-- program_test_logreg_timing.lua
-- Determine how long multinomial logistic regression should run using various implementations
-- Use problem size typically of HEATING.CODE imputation:
--   k = 70
--   nClasses = 14

require 'ifelse'
require 'makeVp'
require 'nn'
require 'optim'
require 'printTableValue'
require 'printTensorValue'
require 'Random'
require 'Timer'
require 'torch'

-- return table containing all the data
local function makeData(nClasses, nFeatures, nSamples)
   local X = torch.rand(nSamples, nFeatures)
   local y = Random():integer(nSamples, 1, nClasses)
   return {X = X, y = y, nClasses = nClasses, nFeatures = nFeatures, nSamples = nSamples}
end

-- implementation 1: the starting point
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient1(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X

   local target = data.y

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
      local vp = makeVp(0, 'lossGradient')
      vp(1, 'theta', theta)

      local parameters, gradientParameters = model:getParameters()

      if parameters ~= theta then
         parameters:copy(theta)
      end

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      model:backward(input, df_do)  -- set gradientParameters

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 2: remove makeVp
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient2(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X

   local target = data.y

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
      local parameters, gradientParameters = model:getParameters()

      if parameters ~= theta then
         parameters:copy(theta)
      end

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      model:backward(input, df_do)  -- set gradientParameters

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 3: move getParameters out of function call
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient3(data)
   local vp = makeVp(1, 'makeLossGradient3')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X

   local target = data.y
   
   local parameters, gradientParameters = model:getParameters()

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
      local vp = makeVp(0, 'lossGradient')
      vp(1, 'theta', theta)

      if parameters ~= theta then
         parameters:copy(theta)
      end

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      model:backward(input, df_do)  -- set gradientParameters

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 4: require theta == parameters
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
-- parameters   : flattened parameters
local function makeLossGradient4(data)
   local vp = makeVp(1, 'makeLossGradient4')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X

   local target = data.y

   local parameters, gradientParameters = model:getParameters()
   parameters:fill(999)

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
      if true then
         return 0, parameters -- can't get it to work
      end
      local vp = makeVp(1, 'lossGradient')
      vp(1, 'theta', theta)

      --local parameters, gradientParameters = model:getParameters()

      --if parameters ~= theta then
      --   parameters:copy(theta)
      --end
      
      if true then
         print()
         print('test fill')
         printTensorValue('parameters', parameters)
         printTensorValue('filled 123', parameters:fill(123))
         printTensorValue('parameters', parameters)
      end

      if parameters ~= theta then
         print()
         print('not the same')
         printTensorValue('parameters', parameters)
         printTensorValue('theta', theta)
         error('parameters not equal theta')
      end
      print() print('the same')

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      model:backward(input, df_do)  -- set gradientParameters

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end

   return lossGradient, parameters
end

-- implementation 5: unroll function calls
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient5(data)
   local vp = makeVp(2, 'makeLossGradient1')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X
   local target = data.y

   local function lossGradientOriginal(theta)
      local parameters, gradientParameters = model:getParameters()
      if parameters ~= theta then
         parameters:copy(theta)
      end
      gradientParameters:zero()
      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local dloss_do = criterion:backward(output, target)
      model:backward(input, dloss_do)  -- set gradientParameters
      -- don't size average
      return {  -- return intermediate and final values
         loss = loss,
         gradientParameters = gradientParameters,
         output = output,
         dloss_do = dloss_do
      }
   end


   -- upvalues for lossGradient() function
   
   local logSoftMax = nn.LogSoftMax()

   local nSamples = input:size(1)
   local nFeatures = input:size(2)
   local nClasses = data.nClasses
   
   local ones = torch.Tensor(nSamples):fill(1)
   local uProbs = torch.Tensor(nSamples, nClasses)
   local probs = torch.Tensor(nSamples, nClasses)
   local loss = 0
   local dLoss_do = torch.Tensor(nSamples, nClasses)
   local gradWeight = torch.Tensor(nClasses, nFeatures)
   local gradBias = torch.Tensor(nClasses)

   local linearWeight = torch.Tensor(data.nClasses, data.nFeatures):zero()
   local linearBias = torch.Tensor(data.nClasses):zero()

   -- return loss and gradient wrt flat parameters theta
   -- using all the data as a mini batch
   -- ARGS:
   -- theta              : flat parameters
   -- RETURN
   -- loss               : loss at theta parameters
   -- gradientParameters : flat gradient at theta
   local function lossGradient(theta)
      if true then 
         return 0, theta 
      end
      local vp = makeVp(2, 'lossGradient')
      vp(1, 'theta', theta)
      
      local check = true
      local original = nil
      if check then 
         original = lossGradientOriginal(theta)
         printTableValue('original', original)
      end

      -- structure the parameters
      local storage = theta:storage()
      vp(2, 'storage:size()', storage:size(), 'linearWeight', linearWeight, 'linearBias', linearBias)
      local startIndex = 1
      for i = 1, nFeatures do
         vp(2, 'i', i, 'startIndex', startIndex)
         linearWeight[i] = torch.Tensor(storage, startIndex, nFeatures, 1) -- create a view
         startIndex = startIndex + nFeatures
      end

      for i = 1, nFeatures do
         linearBias[i] = theta[startIndex + i - 1]  -- copy the value
      end

      vp(2, 'theta', theta, 'linearWeight', linearWeight, 'linearBias', linearBias)

      -- unrolled   output = model:forward(input)
      -- For Linear, this is (code copied from Linear:updateOutput(input)
      if false then
         local nframe = input:size(1)
         local nunit = self.bias:size(1)
         self.output:resize(nframe, nunit)
         self.ouput:zero():addr(1, input.new(nframe):fill(1), self.bias)
         self.output:addmm(1, input, self.weight:t())
      end
      assert(input:dim() == 2)  -- TODO: remove me
      -- unrolling Linear portion where the output is uProbs (unnormalized probabilities)
      uProbs:zero():addr(1, ones, linearBias) -- uProb_ij = 1 * 1_i * linearBias_j
      uProbs:addmm(1, input, linearWeight:t())
      local probs = logSoftMax:forward(uProbs)
      
      -- for ClassNLLCriterion, this is (code copied from ClassNLL;updateOutput(input, target)
      if false then
         local output = 0
         for i = 1, target:size(1) do
            output = output - input[i][target[i]]
         end
         if self.sizeAverage then
            output = output / target:size(1)
         end
         self.output = output
      end  -- package code

      local loss = 0
      for c = 1, nClasses do
         loss = loss - probs[c][target[c]]
      end
      vp(2, 'loss', loss, 'loss if averaged', loss / nClasses)
      -- don't size average

      -- perhaps check the results of the unrolled forward operation
      if check then
         print('original loss de-averaged', original.loss * nClasses, 'loss', loss)
         printTensorValue('original log probabilities', original.output)
         printTensorValue('log probabilities', probs)
         assertEq(original.loss * nClasses, loss, .0001)
         assertEq(original.output, probs, .0001)
      end

      -- unroll  df_do = criterion:backward(output, target)
      -- for ClassNLLCriterion, this is (code copied from ClassNLLCriterion:updateGradIntput(input, target)
      if false then
         self.gradInput:resizeAs(input)
         self.gradInput:zero()
         local z = -1
         if self.sizeAverage then
            z = z / target:size(1)
         end
         local gradInput = self.gradInput
         for i = 1, target:size(1) do
            gradInput[i][target[i]] = z
         end
         return self.gradInput
      end -- package code

      dLoss_do:zero()
      local z = -1 -- don't size average
      vp(2, 'dLoss_do', dLoss_do, 'nSamples', nSamples, 'target', target)
      for i = 1, nSamples do
         dLoss_do[i][target[i]] = z
      end
      vp(2, 'dLoss_do', dLoss_do)

      -- unroll model:backward(input, dloss_do)
      -- for LogSoftMax, this is code copied from LogSoftMax:updateGradInput(input, gradOutput)
      if false then
         return input.nn.LogSoftMax_updateGradInput(self, input, gradOutput)
      end
      local gradOutputLogSoftMax = logSoftMax:backward(input, dLoss_do)
      vp(2, 'gradOutputLogSoftMax', gradOutputLogSoftMax)
      
      -- for Linear. this is the code copied from Linear:accGradParameters(input, gradOutput, scale)
      -- NOTE: We don't need to compute the gradient wrt the input
      if false then
         local nframe = input:size(1)
         local nunit = self.bias:size(1)
         self.gradWeight:addmm(scale, gradOutput:t(), input)
         self.gradBias:addmv(scale, gradOutput:t(), input.new(nframe):fill(1))
      end

      gradWeight:addmm(1, gradOutputLogSoftMax:t(), input)
      gradBias:addmv(1, gradOutputLogSoftMax:t(), ones)
      vp(2, 'gradWeights', gradWeight, 'gradBias', gradBias)

      -- concatenate and flatten parameters (mimic Module:parameters())
      -- flatten the gradient
      local flatGradient = torch.Tensor(theta:size(1))
      local index = 1
      for i = 1, nFeatures do
         for c = 1, nClasses do
            flatGradient[index] = gradWeights[nFeatures][nClasses]
            index = index + 1
         end
      end
      for c = 1, nClasses do
         flatGradient[index] = gradBias(c)
         index = index + 1
      end
      
      vp(2, 'flatGradient', flatGradient)
      stop()

      return loss, flatGradient
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 6: just compute gradParameters, not also gradOutput
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient6(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X

   local target = data.y

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
      local vp = makeVp(0, 'lossGradient')
      vp(1, 'theta', theta)

      local parameters, gradientParameters = model:getParameters()

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
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 7: 2 + 3 + 6
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function makeLossGradient7(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local model = nn.Sequential()
   model:add(nn.Linear(data.nFeatures, data.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X
   local target = data.y
   local parameters, gradientParameters = model:getParameters()

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradient(theta)
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
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- compare timings of implementations
local function compareImplementations(config, data, implementations)
   -- return cpu seconds and wallclock seconds to run
   -- the implemenation created by maker(data) for nIterations
   local function timeCalls(data, maker, nIterations)
      local vp = makeVp(0, 'timeCalls')
      vp(1, 'maker', maker, 'nIterations', nIterations)
      lossGradient, parameters = maker(data)
      vp(2, 'lossGradient', lossGradient, 'parameters', parameters)
      if type(parameters) == 'number' then
         vp(2, 'resetting parameters')
         parameters = torch.Tensor(parameters):zero()  -- implementation 1, 2, 3 return nParameters, not actual parameters
      end

      -- time execution of many iterations of the lossGradient function
      local timer = Timer()
      for iteration = 1, nIterations do
         local loss, newParameters = lossGradient(parameters)
         parameters = newParameters
      end

      return timer:cpuWallclock() -- return cpu, wallclock
   end

   -- determine execution times for each implementation
   local times = {}  -- key == implementation number, value == table{cpu=, wallclock=}
   local which = 'all'
   --local which = 6
   for i, implementation in pairs(implementations) do
      if which == i or which == 'all' then
         collectgarbage()
         local cpu, wallclock = timeCalls(data, implementation.maker, config.nIterations)
         times[i] = {cpu = cpu, wallclock = wallclock}
      end
   end

   -- print comparison of execution times
   --printTableValue('times', times)
   print()
   print(ifelse(jit, '', 'not ') .. 'using luajit')
   print(string.format('timings in seconds per iterations over %d iterations', config.nIterations))
   print(string.format('   implemenation %25s %8s       %%1 %8s %%1', ' ', 'cpu', 'wallclock'))
   local cpu1 = times[1].cpu
   local wallclock1 = times[1].wallclock
   cpu1 = ifelse(cpu1 == nil, 0, cpu1)
   wallclock1 = ifelse(wallclock1 == nil, 0, wallclock1)
   for i, time in pairs(times) do
      print(string.format('%1d %45s %8.6f %3.0f %8.6f %3.0f', 
                           i, 
                           implementations[i].description, 
                           time.cpu / config.nIterations, 
                           time.cpu / cpu1 * 100,
                           time.wallclock / config.nIterations,
                           time.wallclock / wallclock1 * 100))
   end
end

-- MAIN PROGRAM

local vp = makeVp(2, 'main program')
print()
print('************************************************** starting program_test_logreg_timing')
print()

-- configure

torch.manualSeed(123)

local config = {
   nIterations = 100000,
   compareImplementations = true,
   nSamples = 70,
   nFeatures = 8,
   nClasses = 14, 
}

printTableValue('config', config)

-- build table of all the implementations
local implementations = {}
local function implementation(index, maker, description)
   implementations[index] = {maker = maker, description = description}
end

implementation(1, makeLossGradient1, 'original')
implementation(2, makeLossGradient2, 'remove makeVp')
implementation(3, makeLossGradient3, 'move getParameters out of function call')
implementation(4, makeLossGradient4, 'require theta == parameters')
implementation(5, makeLossGradient5, 'unroll + only gradOutput')
implementation(6, makeLossGradient6, 'just gradParameters')
implementation(7, makeLossGradient7, '2 + 3 + 6')
printTableValue('implementations', implementations)

      
local data = makeData(config.nClasses, config.nFeatures, config.nSamples)
printTableValue('data', data)

if config.compareImplementations then
   print('comparing implementations')
   compareImplementations(config, data, implementations)
end

print('done')
