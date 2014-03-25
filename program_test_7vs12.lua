-- program_test_7vs12.lua
-- carefully compare results and timing for these two implementations of log reg lossGradient
-- check my understanding

require 'argmax'
require 'assertEq'
require 'HierarchialTable'
require 'ifelse'
require 'nn'
require 'printTableVariable'
require 'printAllVariables'
require 'printVariable'
require 'printVariables'
require 'tableFilter'
require 'tableFoldValues'
require 'tableMerge'
require 'Random'
require 'Timer'
require 'torch'

local function augment(X)--{{{
   local nSamples = X:size(1)
   local nFeatures = X:size(2)
   local augmentedX = torch.Tensor(nSamples, nFeatures + 1)
   for s = 1, nSamples do
      augmentedX[s][1] = 1
      for f = 1, nFeatures do
         augmentedX[s][f + 1] = data.X[s][f]
      end
   end
   return augmentedX
end--}}}

local function makeData(which)--{{{
   local nClasses = ifelse(which == 'small', 3, 14)
   local nFeatures = ifelse(which == 'small', 4, 8)
   local nSamples = ifelse(which == 'small', 5, 70)
   data = {
      which = which,
      nClasses = nClasses,
      nFeatures = nFeatures,
      nSamples = nSamples,
      X = torch.rand(nSamples, nFeatures),
      y = Random:integer(nSamples, 1, nClasses),
   }
   data.augmentedX = augment(data.X)
   return data
end--}}}

local function makeModuleScore7(data)--{{{
   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local input = data.X

   local function f()
      return linearModule:forward(input)
   end

   return {
      component = 'scores',
      architecture = 'nn',
      implementations = {
         {description='', f=f},
      },
      bias = linearModule.bias,
      weight = linearModule.weight,
   }
end--}}}

local function makeModuleCopyTheta7(data)--{{{
   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmaxModule = nn.LogSoftMax()
   
   local model = nn.Sequential()
   model:add(linearModule)
   model:add(logsoftmaxModule)
   
   local parameters, gradientParameters = model:getParameters()
   --printTensorValue('parameters', parameters)

   local theta = parameters:clone()

   local function f()
      if parameters ~= theta or true then
         parameters:copy(theta)
      end
   end

   return {
      component='copyTheta',
      architecture='nn',
      implementations={
         {description='', f=f},
      },
   }
end--}}}

local function makeModuleOutput7(data)--{{{
   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmaxModule = nn.LogSoftMax()
   
   local model = nn.Sequential()
   model:add(linearModule)
   model:add(logsoftmaxModule)
   
   local parameters, gradientParameters = model:getParameters()

   local criterion = nn.ClassNLLCriterion()

   local scores = linearModule:forward(data.X)

   local function f()
      return logsoftmaxModule:forward(scores)
   end

   return {
      component='output',
      architecture='nn',
      implementations={
         {description='', f=f},
      },
   }
end--}}}

local function makeModuleLoss7(data)--{{{
   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmaxModule = nn.LogSoftMax()
   
   local model = nn.Sequential()
   model:add(linearModule)
   model:add(logsoftmaxModule)
   
   local parameters, gradientParameters = model:getParameters()

   local criterion = nn.ClassNLLCriterion()

   local scores = linearModule:forward(data.X)
   local output = logsoftmaxModule:forward(scores)
   
   local target = data.y

   local function f()
      return criterion:forward(output, target)
   end

   return {
      component='loss',
      architecture='nn',
      implementations = {
         {description='', f=f},
      },
   }
end--}}}

local function makeModuleGradient7(data)--{{{
   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmaxModule = nn.LogSoftMax()
   
   local model = nn.Sequential()
   model:add(linearModule)
   model:add(logsoftmaxModule)
   
   local parameters, gradientParameters = model:getParameters()

   local criterion = nn.ClassNLLCriterion()

   local input = data.X
   local target = data.y
   
   local output = model:forward(input)
   local loss = criterion:forward(output, target)
   
   local function f()
      local df_do = criterion:backward(output, target)
      local dmodule2_do = logsoftmaxModule:backward(input, df_do)
      linearModule:accGradParameters(input, dmodule2_do)  -- set gradientParameters

      -- don't normalize for input size
      return loss, gradientParameters
   end

   local function lossGradientFunction(theta)--{{{
      --local vp = makeVp(0, 'lossGradient')
      --vp(1, 'theta', theta)


      if parameters ~= theta then
         parameters:copy(theta)
      end

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      --model:backward(input, df_do)  -- set gradientParameters
      --printTableValue('model', model)
      local dmodule2_do = model.modules[2]:backward(input, df_do)
      model.modules[1]:accGradParameters(input, dmodule2_do)  -- set gradientParameters
      

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end--}}}
   
   return {
      component= 'gradient',
      architecture='nn',
      implementations= {
         {description='', f=f},
      },
   }
end--}}}

local function makeModuleScore12(data)--{{{
   local augmentedX = data.augmentedX
   local theta = data.theta
   
   local function f()
      --printTensorValue('X', X) printTensorValue('theta', theta)
      return torch.mm(augmentedX, theta:t()) -- NOTE differs from nn package
   end

   return {
      component= 'scores',
      architecture = 'direct',
      implementations={
         {description='', f=f},
      },
   }
end--}}}

local function softmaxa(X) -- divide then multiply {{{
   local nSamples = X:size(1)
   local nClasses = X:size(2)

   local largestVector = torch.max(X, 2)
   local largestMatrix = 
      torch.Tensor(largestVector:storage(), 1, nSamples, 1, nClasses, 0)

   local e = torch.exp(X - largestMatrix)

   local sumVector = torch.sum(e, 2)
   
   local oneNSamples = torch.Tensor(nSamples):fill(1)
   
   local z1Vector = torch.cdiv(oneNSamples, sumVector)
   local z1Matrix = 
      torch.Tensor(z1Vector:storage(), 1, nSamples, 1, nClasses, 0)

   local probabilities = torch.cmul(e, z1Matrix)
   return probabilities
end--}}}

local function softmaxb(X) --only divide {{{
   -- divide, not divide then multiply
   local nSamples = X:size(1)
   local nClasses = X:size(2)

   local largestVector = torch.max(X, 2)
   local largestMatrix = 
      torch.Tensor(largestVector:storage(), 1, nSamples, 1, nClasses, 0)

   local e = torch.exp(X - largestMatrix)

   local sumVector = torch.sum(e, 2)
   local sumMatrix = torch.Tensor(sumVector:storage(),
                                  1,
                                  nSamples,
                                  1,
                                  nClasses, 
                                  0)
   local probabilities = torch.cdiv(e, sumMatrix)
   return probabilities
end--}}}

local function softmaxc(X) -- ignore overflow potential {{{
   local nSamples = X:size(1)
   local nClasses = X:size(2)
   local e = torch.exp(X)
   local sumVector = torch.sum(e, 2)
   local sumMatrix = torch.Tensor(sumVector:storage(), 1, nSamples, 1, nClasses, 0)
   local result = torch.cdiv(e, sumMatrix)
   return result
end--}}}

local function makeModuleOutput12(data)--{{{

   local scores = torch.mm(data.augmentedX, data.theta:t()) -- NOTE differs from nn package
   
   local function fa()
      return softmaxa(scores)
   end

   local function fb()
      return softmaxb(scores)
   end

   local function fc()
      return softmaxc(scores)
   end

   local function prob()
      -- input is the scores
      --printTensorValue('scores', scores)
      local nSamples = scores:size(1)
      local nClasses = scores:size(2)
      local smallestVector = torch.min(scores, 2)
      local smallestMatrix = torch.Tensor(smallestVector:storage(), 1, nSamples, 1, nClasses, 0)
      local diff = scores - smallestMatrix
      --printTensorValue('smallestMatrix', smallestMatrix)
      --printTensorValue('diff', diff)
      local sumVector = torch.sum(diff, 2)
      local sumMatrix = torch.Tensor(sumVector:storage(), 1, nSamples, 1, nClasses, 0)
      local result = torch.cdiv(diff, sumMatrix)
      return result
   end

   return {
      component= 'output',
      architecture='direct',
      implementations = {
         {description='divide then multiply', f=fa},
         {description='only divide', f=fb},
         {description='ignore overflow potential', f=fc},
         {description='not softmax', f=prob},
      },
   }
end--}}}

local function makeModuleLoss12(data)--{{{

   local scores = torch.mm(data.augmentedX, data.theta:t()) -- NOTE differs from nn package
   local p = softmaxa(scores)
   local y = data.y
   local nSamples = data.nSamples

   local function f1() -- neg log likeihood
      local objective = 0
      for sampleIndex = 1, nSamples do
         objective = objective - math.log(p[sampleIndex][y[sampleIndex]])
      end
      return objective
   end

   local function f2() -- neg sum prob[c]
      -- NOTE: requires a different gradient function, which needs to
      -- be designed and implemented
      local objective = 0
      for sampleIndex = 1, nSamples do
         objective = objective - p[sampleIndex][y[sampleIndex]]
      end
      return objective
   end
   
   return {
      component='loss',
      architecture='direct',
      implementations = {
         {description='', f=f1},
         --{description='neg log likelihood', f = f1},
         --{description='neg sum prob[c]', f=f2},
      }
   }
end--}}}

local function makeModuleGradient12(data)--{{{

   local scores = torch.mm(data.augmentedX, data.theta:t()) -- NOTE differs from nn package
   local p = softmaxa(scores)
   local y = data.y
   local nSamples = data.nSamples

   local objective = 0
   for sampleIndex = 1, nSamples do
      objective = objective - math.log(p[sampleIndex][y[sampleIndex]])
   end

   local nClasses = data.nClasses
   local nFeatures = data.nFeatures
   local nSamples = data.nSamples

   -- precompute all the targets
   local targets = torch.Tensor(nClasses, nClasses):zero()
   for c = 1, nClasses do
      targets[c][c] = 1
   end
   
   local X = data.augmentedX
   local theta = data.theta
   local L2 = 0
   
   local function f()
      local sumGradient = torch.Tensor(nClasses, nFeatures + 1):zero()
      for sampleIndex = 1, nSamples do

--       local targetForSample = torch.Tensor(nClasses):zero()
--       targetForSample[y[sampleIndex]] = 1

         local targetForSample = targets[y[sampleIndex]]

         local pForSample = p:select(1, sampleIndex)  -- select row

         local xForSample = X:select(1, sampleIndex)  -- select row

         --printTensorValue('p', p) printTensorValue('X', X)
         --printVariables('targetForSample', 'pForSample', 'xForSample')

         local gradient = torch.ger(pForSample - targetForSample, xForSample)
         --printVariable('gradient')

         --sumGradient = sumGradient + torch.ger(pForSample - targetForSample, xForSample)
         sumGradient = sumGradient + gradient
      end
      local objectiveRegularized = objective + L2 * torch.sum(theta)
      sumGradient = sumGradient + theta * L2  -- add in regularizer
      return objectiveRegularized, sumGradient
   end


   return {
      component='gradient',
      architecture='direct',
      implementations={
         {description='', f=f},
      },
   }
end--}}}

-- return total CPU time for nClass of fn()--{{{
local function timeIterations(nCalls, fn)
   local timer = Timer()
   for i = 1, nCalls do 
      fn()
   end
   return timer:cpu()
end--}}}

local function timeComponents(data, modules, cpuTimes)--{{{
   for componentName, table1 in pairs(modules.table) do 
      for architectureName, table2 in pairs(table1) do
         for description, f in pairs(table2) do
            local totalcpu = timeIterations(data.nIterations, f)
            local cpu = totalcpu / data.nIterations
            print(string.format('component %10s arch %10s %25s cpu sec %10.6f',
                  componentName,
                  architectureName,
                  description,
                  cpu))
            cpuTimes:put(componentName, architectureName, description, cpu)
         end
      end
   end
   return cpuTimes
end--}}}

local function makeTheta(bias, weight)--{{{
   --printTensorValue('bias', bias) printTensorValue('weight', weight)
   local theta = torch.Tensor(data.nClasses, data.nFeatures + 1)
   --printTensorValue('theta', theta)
   for c = 1, data.nClasses do
      theta[c][1] = bias[c]
      for f = 1, data.nFeatures do
         theta[c][f + 1] = weight[c][f]
      end
   end
   return theta
end--}}}

local function bestTimes(cpuTimes, arch)--{{{
   local sumCpu = 0
   for componentName, table1 in pairs(cpuTimes.table) do
      for architectureName, table2 in pairs(table1) do
         if architectureName == arch then
            local lowestCpu = math.huge
            for description, cpu in pairs(table2) do
               if cpu < lowestCpu then
                  lowestCpu = cpu
               end
            end
            sumCpu = sumCpu + lowestCpu
         end
      end
   end
   return sumCpu
end--}}}

-- MAIN program
print('**************************************************************')
torch.manualSeed(123)

local data = makeData('small')
local data = makeData('large')
data.nIterations = 1000
--data.nIterations = 10000
data.nIterations = 100000
local m = makeModuleScore7(data)
printTableValue('m', m)
data.theta = makeTheta(m.bias, m.weight)
printTableValue('data', data)

-- create all modules
local modules = HierarchialTable(3)
local function save(t)
   --print('\n*************')
   --printTableValue('save t', t)
   assert(type(t) == 'table')
   assert(type(t.component) == 'string')
   assert(type(t.architecture) == 'string')
   assert(type(t.implementations) == 'table')
   for _, implementation in pairs(t.implementations) do
      assert(type(implementation.description == 'string'))
      assert(type(implementation.f == 'function'))
      modules:put(t.component, 
                  t.architecture, 
                  implementation.description,
                  implementation.f)
   end
end

save(makeModuleScore7(data))
save(makeModuleCopyTheta7(data))
save(makeModuleOutput7(data))
save(makeModuleLoss7(data))
save(makeModuleGradient7(data))

save(makeModuleScore12(data))
save(makeModuleOutput12(data))
save(makeModuleLoss12(data))
save(makeModuleGradient12(data))

--print('modules')
--modules:print(io.stdout)

local cpuTimes = HierarchialTable(3)
print(string.format('per iteration CPU times on average for %d iterations', data.nIterations))
timeComponents(data, modules, cpuTimes)
--print('cpuTimes')
--cpuTimes:print()

-- compare total times for best version of each architecture
local function printTotalCpu(arch)
   local totalCpu = bestTimes(cpuTimes, arch)
   print(string.format('best times for arch %10s = %f', arch, totalCpu))
end

printTotalCpu('nn')
printTotalCpu('direct')

print('done')
