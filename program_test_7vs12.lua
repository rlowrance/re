-- program_test_7vs12.lua
-- carefully compare results and timing for these two implementations of log reg lossGradient
-- check my understanding

require 'argmax'
require 'assertEq'
require 'ifelse'
require 'nn'
require 'printTableVariable'
require 'printAllVariables'
require 'printVariable'
require 'printVariables'
require 'Random'
require 'Timer'
require 'torch'

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
   return data
end--}}}
 
-- implementation 7: 2 + 3 + 6--{{{
-- return function that retuns loss and gradient at specified parameters theta
-- ARGS
-- data          : data table with X, y
-- RETURNS 
-- initialBias   : 1D Tensor
-- initialWeight : 1D Tensor
-- linear        : function(X) that transforms X via a linear transformation
-- forward       : function(X) that returns the predictions
-- lossGradient  : function(theta) --> loss, gradient
-- nParameters   : integer > 0, number of flattened parameters
local function implementation7(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local linearModule = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmaxModule = nn.LogSoftMax()
   local model = nn.Sequential()
   model:add(linearModule)
   model:add(logsoftmaxModule)
-- model:add(nn.Linear(data.nFeatures, data.nClasses))
-- model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local X = data.X
   local function linearFunction()
      return linearModule:forward(X)
   end

   local X = data.X
   local function forwardFunction()
      return model:forward(X)
   end

   local X = data.X
   local y = data.y
   local function lossFunction()
      local output = model:forward(X)
      local result = criterion:forward(output, y)
      return result
   end

   local parameters, gradientParameters = model:getParameters()
   local input = data.X
   local target = data.y
   local output = model:forward(input)
   local loss = criterion:forward(output, target)
   local function backwardFunction()
      local df_do = criterion:backward(output, target)
      --model:backward(input, df_do)  -- set gradientParameters
      --printTableValue('model', model)
      local dmodule2_do = model.modules[2]:backward(input, df_do)
      model.modules[1]:accGradParameters(input, dmodule2_do)  -- set gradientParameters
      return gradientParameters
   end


   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   local function lossGradientFunction(theta)
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

   return linearModule.bias, 
          linearModule.weight, 
          {linearFunction}, 
          {forwardFunction}, 
          {lossFunction},
          {lossGradientFunction}
end--}}}

-- implementation 12: Yann's idea in batch mode--{{{
-- RETURNS
-- linear : function(X) 
-- forward : function(X) --> predictions
local function implementation12(data)
   local vp = makeVp(1, 'makeLossGradient11')

   local nClasses = data.nClasses
   local nSamples = data.X:size(1)
   local nFeatures = data.X:size(2)

   local oneNClasses = torch.Tensor(nClasses):fill(1)
   local oneNSamples = torch.Tensor(nSamples):fill(1)
   local one_nClasses_1  = torch.Tensor(nClasses, 1):fill(1)

   -- Yann's logistic regression training updated to handle X (matrix) instead of x (vector)

   -- softmax of a matrix considered row by row--{{{
   -- ARGS
   -- X             : 2D Tensor of scores size nSamples x nClasses
   -- RETURNS
   -- probabilities : 2D Tensor of probabilities size nSamples x nClasses
   --                 each row sums to 1
   local function softmax1(X)
      -- original code for when x is a vector
--    local largest = torch.max(x)
--    local e = torch.exp(x-largest)
--    local z1 = 1/torch.sum(e)
--    return e * z1

      --TODO: backport changes to Implementaton 12
      -- X is the scores matrix, nSamples x nClasses
      --printTensorValue('X', X)
      local largestVector = torch.max(X, 2)
      local largestMatrix = 
         torch.Tensor(largestVector:storage(), 1, nSamples, 1, nClasses, 0)
      
      local e = torch.exp(X - largestMatrix)

      local sumVector = torch.sum(e, 2)
      --printAllVariables() printTensorValue('oneNSamples', oneNSamples)
      local z1Vector = torch.cdiv(oneNSamples, sumVector)
      local z1Matrix = 
         torch.Tensor(z1Vector:storage(), 1, nSamples, 1, nClasses, 0)

      local probabilities = torch.cmul(e, z1Matrix)
      return probabilities
   end

   local function softmax2(X)
      -- divide, not divide then multiply
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
   end

   -- this implementation is fastest
   -- ignore overflow problem
   -- divide, not divide then multiply
   local function softmax3(X) -- ignore overflow problem
      local e = torch.exp(X)
      local sumVector = torch.sum(e, 2)
      local sumMatrix = torch.Tensor(sumVector:storage(), 1, nSamples, 1, nClasses, 0)
      local result = torch.cdiv(e, sumMatrix)
      return result
   end

   local function softmax4(X)  -- just divide directly
      local largestVector = torch.max(X, 2)
      local largestMatrix = 
         torch.Tensor(largestVector:storage(), 1, nSamples, 1, nClasses, 0)
      
      local e = torch.exp(X - largestMatrix)

      local sumVector = torch.sum(e,2)
      local sumMatrix = torch.Tensor(sumVector:storage(), 1, nSamples, 1, nClasses, 0)
      local probabilities = torch.cdiv(e, sumMatrix)
      return probabilities
   end

   local softmaxSequence = {softmax1, softmax2, softmax3, softmax4}
   
   local function softmax(X, implementation)
      assert(implementation >= 1)
      assert(implementation <= 4)
      return softmaxSequence[implementation](X)
   end--}}}

   local theta = data.theta
   local augmentedX = torch.Tensor(nSamples, nFeatures + 1)
   for s = 1, nSamples do
      augmentedX[s][1] = 1
      for f = 1, nFeatures do
         augmentedX[s][f + 1] = data.X[s][f]
      end
   end
   local y = data.y

   -- return linear(augmentedX, theta) --> 2D Tensor
   local function linear()
      --printTensorValue('X', X) printTensorValue('theta', theta)
      return torch.mm(augmentedX, theta:t()) -- NOTE differs from impl 7
   end

   -- return softmax(linear(augmentedX, theta)) --> 2D Tensor of probabilities
   local function forward(implementation)
      local s= torch.mm(augmentedX, theta:t())
      return softmax(s, implementation)
   end

   local function forward1() return forward(1) end
   local function forward2() return forward(2) end
   local function forward3() return forward(3) end
   local function forward4() return forward(4) end
   
   local forwards = {forward1, forward2, forward3, forward4}

   -- return NLL of sum of prob of correct classes
   local function loss(implementation)
      local s= torch.mm(augmentedX, theta:t())
      local p = softmax(s, implementation)

      local objective= 0
--    print('nSamples', nSamples)
--    printTensorValue('p', p)
--    printTensorValue('y', y)
      for sampleIndex = 1, nSamples do
--       print('sampleIndex', sampleIndex)
         objective = objective - math.log(p[sampleIndex][y[sampleIndex]])
      end
      return objective
   end

   local function loss1() return loss(1) end
   local function loss2() return loss(2) end
   local function loss3() return loss(3) end
   local function loss4() return loss(4) end

   local losses = {loss1, loss2, loss3, loss4}

   -- forward and backward for multinomial logistic regression--{{{
   -- ARGS
   -- X         : 2D Tensor of samples size nSamples x nFeatures
   -- y         : 1D Tensof of classes size nFeatures
   -- theta     : 2D Tensor of parameters size nClasses x nFeatures
   -- L2        : number, importance of L2 regularizer
   -- RETURNS
   -- objective : number, total (not average) loss for all X and y using theta parameters
   -- gradient  : 2D Tensor of same size as theta, gradient
   local function LogregFpropBprop(X,y,theta,L2) 
--    original code (corrected) from Yann
--    local s = torch.mv(theta,x)
--    local p = softmax(s)
--    --local objective = -log(p[y])
--    local objective = -math.log(p[y])
--    local target = torch.Tensor(theta:size(1)):zero()
--    target[y] = 1
--    --local gradient = torch.ger( (p[y] - target), x) - theta*L2
--    local gradient = torch.ger( - (target - p[y]), x) - theta*L2  -- get == outer product
--    return objective, gradient

      assert(X:nDimension() == 2)      -- X is nSamples x nFeatures
      assert(X:size(1) == 70)
      assert(y:nDimension() == 1)      -- y is nSamples
      local s = torch.mm(theta, X:t()) -- s is nClasses x nSamples
      local p = softmax(s)             -- p is nClasses x nSamples, each row sums to 1
      --printVariables('s', 'p', 'X', 'y')

      local objective = 0
      local sumGradient = torch.Tensor(nClasses, nFeatures):zero()
      for sampleIndex = 1, nSamples do
         objective = objective - math.log(p[y[sampleIndex]][sampleIndex])

         local targetForSample = torch.Tensor(nClasses):zero()
         targetForSample[y[sampleIndex]] = 1

         local pForSample = p:select(2, sampleIndex)  -- select column

         local xForSample = X:select(1, sampleIndex)  -- select row

         --printVariables('targetForSample', 'pForSample', 'xForSample')

         sumGradient = sumGradient + torch.ger(pForSample - targetForSample, xForSample)
      end
      local objectiveRegularized = objective + L2 * torch.sum(theta)
      sumGradient = sumGradient + theta * L2  -- add in regularizer
      if true then
         return objectiveRegularized, sumGradient
      end
         
      printVariables('sumGradient')
      stop()
      printVariables('objective')

      local target = torch.Tensor(theta:size(1)):zero()
      printVariables('target', 'y')
      target[y] = 1
      printVariable('target')

      local gradient = torch.ger(p - target, x) - theta*L2


      printVariable('gradient')
      stop()
      if true then return end
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      --local gradient = torch.ger( (p[y] - target), x) - theta*L2
      local gradient = torch.ger( - (target - p[y]), x) - theta*L2
      return objective, gradient -- NOTE: should ravel the gradient
   end--}}}

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch

   local fakeTheta = torch.rand(nClasses, nFeatures)
   local L2 = 0
   local X = data.X
   local y = data.y

   local function lossGradient(theta)
      return  LogregFpropBprop(X, y, fakeTheta, L2)
      --return  LogregFpropBprop(X, yAsLongTensor, fakeTheta, L2)
   end

   return {linear}, forwards, losses, lossGradient 
end--}}}

local function time(nCalls, fn)--{{{
   local timer = Timer()
   for i = 1, nCalls do 
      fn()
   end
   return timer:cpu()
end--}}}

-- testLinear: return cpu times for nIterations of each--{{{
local function testLinear(nnLinear, myLinear, data)
-- printAllVariables()
   local nnResult = nnLinear()
   local myResult = myLinear()
-- printTensorValue('nnResult', nnResult)
-- printTensorValue('myResult', myResult)
   assertEq(nnResult, myResult, .0001)
   
   local cpuNn = time(data.nIterations, nnLinear)
   local cpuMy = time(data.nIterations, myLinear)

   return cpuNn, cpuMy
end--}}}
 
-- testForward: return cpu times for nIterations of each--{{{
-- check that results are identical
local function testForward(nnForward, myForward, data)
   local nnResult = nnForward()
   local myResult = myForward()
   local myResultLog = torch.log(myResult)
   assertEq(nnResult, myResultLog, .0001)
   
   -- obtain cpu times
   local cpuNn = time(data.nIterations, nnForward)
   local cpuMy = time(data.nIterations, myForward)

   return cpuNn, cpuMy
end--}}}

local function testLinearOLD()--{{{
   local linear = nn.Linear(nFeatures, nClasses)
   local bias = linear.bias
   local weight = linear.weight
   printAllVariables()

   local data = makeData(nClasses, nFeatures, nSamples)
   local output = linear:updateOutput(data.X)
   printVariable('output')
   
   -- compare nn output to our own output
   local theta = torch.Tensor(nClasses, nFeatures + 1)
   for c = 1, nClasses do
      theta[c][1] = bias[c]
      for f = 1, nFeatures do
         theta[c][f + 1] = weight[c][f]
      end
   end
   printVariable('theta')
   
   local augmentedX = torch.Tensor(nSamples, nFeatures + 1)
   for s = 1, nSamples do
      augmentedX[s][1] = 1
      for f = 1, nFeatures do
         augmentedX[s][f + 1] = data.X[s][f]
      end
   end
   
   local myOutput = torch.mm(theta, augmentedX:t())
   printVariables('output', 'myOutput')
   assertEq(output, myOutput, .0001)
end--}}}

local function testLoss(nnLoss, myLoss, data)--{{{
   assert(type(nnLoss) == 'function')
   assert(type(myLoss) == 'function')
   local nnResult = nnLoss()
   local myResult = myLoss() / data.nSamples  -- convert to average value
   assertEq(nnResult, myResult, .0001)
   
   -- obtain cpu times
   local cpuNn = time(data.nIterations, nnLoss)
   local cpuMy = time(data.nIterations, myLoss)

   return cpuNn, cpuMy
end--}}}

local function testBackward(nnBackward, myBackward, data)--{{{
   local nnResult = nnBackward()
   local myResult = myBackward()
   assertEq(nnResult, myResult, .0001)
   
   -- obtain cpu times
   local cpuNn = time(data.nIterations, nnBackward)
   local cpuMy = time(data.nIterations, myBackward)

   return cpuNn, cpuMy
end--}}}

local function test(data)--{{{

   local function makeTheta(bias, weight)
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
   end

   local function testSeq(name, testComponent, nnFunctions, myFunctions, data)
      assert(type(nnFunctions) == 'table')
      assert(type(myFunctions) == 'table')
      for i = 1, #nnFunctions do
         for j = 1, #myFunctions do
            local nnCpu, myCpu = 
               testComponent(nnFunctions[i], myFunctions[j], data)
            print(string.format('cpu secs for %d iterations of %10s: nn[%d] %f my[%d] %f (%3.0f%%)',
                                data.nIterations, 
                                name, 
                                i,
                                nnCpu, 
                                j, 
                                myCpu, 
                                myCpu / nnCpu * 100))
         end
      end
   end

   local nnBias, nnWeight, nnLinears, nnForwards, nnLosses, nnBackwards = 
      implementation7(data)
   -- augment data to include initial theta from the nn package's implementation
   data.theta = makeTheta(nnBias, nnWeight)
   local myLinears, myForwards, myLosses, myBackwards = 
      implementation12(data)
   
   print('which', data.which)
   testSeq('linear', testLinear, nnLinears, myLinears, data)
   testSeq('forward', testForward, nnForwards, myForwards, data)
   testSeq('loss', testLoss, nnLosses, myLosses, data)
   testSeq('backward', testBackward, nnBackwards, myBackwards, data)
end--}}}

print('**************************************************************')
torch.manualSeed(123)
local data = makeData('small')
--local data = makeData('large')
data.nIterations = 1000
--data.nIterations = 10000
test(data)
error('write more')
