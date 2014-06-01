-- program_test_understanding_nn.lua
-- check my understanding

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

local function makeData(which)
   local nClasses = ifelse(which == 'small', 3, 14)
   local nFeatures = ifelse(which == 'small', 4, 8)
   local nSamples = ifelse(which == 'small', 5, 70)
   data = {
      nClasses = nClasses,
      nFeatures = nFeatures,
      nSamples = nSamples,
      X = torch.rand(nSamples, nFeatures),
      y = Random:integer(nSamples, 1, nClasses),
   }
   return data
end
 
-- implementation 7: 2 + 3 + 6
-- return function that retuns loss and gradient at specified parameters theta
-- RETURN 
-- initialBias : 1D Tensor
-- initialWeight : 1D Tensor
-- linear  : function(X) that transforms X via a linear transformation
-- forward : function(X) that returns the predictions
-- lossGradient : function(theta) --> loss, gradient
-- nParameters  : integer > 0, number of flattened parameters
local function implementation7(data)
   local vp = makeVp(1, 'makeLossGradient1')

   local linear = nn.Linear(data.nFeatures, data.nClasses)
   local logsoftmax = nn.LogSoftMax()
   local model = nn.Sequential()
   model:add(linear)
   model:add(logsoftmax)
-- model:add(nn.Linear(data.nFeatures, data.nClasses))
-- model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local input = data.X
   local target = data.y
   local parameters, gradientParameters = model:getParameters()

   local function forward(X)
      return model:forward(X)
   end

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

   return linear.bias, linear.weight, linear, forward, lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 12: Yann's idea in batch mode
-- RETURNS
-- linear : function(X) 
-- forward : function(X) --> predictions
local function implementation12(data)
   local vp = makeVp(1, 'makeLossGradient11')

   local nClasses = data.nClasses
   local nSamples = data.X:size(1)
   local nFeatures = data.X:size(2)

   local oneNClasses = torch.Tensor(nClasses):fill(1)
   local one_nClasses_1  = torch.Tensor(nClasses, 1):fill(1)

   -- Yann's logistic regression training updated to handle X (matrix) instead of x (vector)

   -- softmax of a matrix considered row by row
   -- ARGS
   -- X             : 2D Tensor of scores size nClasses x nSamples
   -- RETURNS
   -- probabilities : 2D Tensor of probabilities for each sample of size nClasses x nSamples
   --                 each row sums to 1
   local function softmax(X)
      -- original code for when x is a vector
--    local largest = torch.max(x)
--    local e = torch.exp(x-largest)
--    local z1 = 1/torch.sum(e)
--    return e * z1

      -- X is the scores matrix, 
      local largest_nClasses_1 = torch.max(X,2)  -- size nClasses x 1
      local largest_nClasses_nSamples = torch.Tensor(largest_nClasses_1:storage(), 1, nClasses, 1, nSamples, 0)

      local e_nClasses_nSamples = torch.exp(X-largest_nClasses_nSamples) -- of size nClasses x nSamples

      --z1 is the normalizer for the probabilities
      local sum_nClasses_1  = torch.sum(e_nClasses_nSamples, 2)
      local z1_nClasses_1 = torch.cdiv(one_nClasses_1, sum_nClasses_1)
      local z1_nClasses_nSamples = torch.Tensor(z1_nClasses_1:storage(), 1, nClasses, 1, nSamples, 0)
      --printVariables('X', 'z1_nClasses_nSamples')
      if false then
         local result = torch.cmul(e_nClasses_nSamples, z1_nClasses_nSamples)
         printVariables('result')
      end

      return torch.cmul(e_nClasses_nSamples, z1_nClasses_nSamples)
   end

   local function linear(X, theta)
      return torch.mm(theta, X)
   end

   local function foward(X, theta)
      local s= torch.mm(theta, X:t())
      return softmax(s)
   end
   

   -- forward and backward for multinomial logistic regression
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
   end


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

   return linear, forward, lossGradient, (data.nFeatures + 1) * data.nClasses
end

local function time(nCalls, fn, arg1)
   local timer = Timer()
   for i = 1, nCalls do 
      fn(arg1)
   end
   return timer:cpu()
end

-- testLinear: return cpu times for nIterations of each
local function testLinear(nnLinear, myLinear, data)
   printAllVariables()
   local nnResult = nnLinear(data.X)
   local myResult = myLinear(data.X)
   printTensorValue('nnResult', nnResult)
   printTensorValue('myResult', myResult)
   assertEq(nnResult, myResult:t(), .0001)
   
   local cpuNn = time(data.nIterations, nnForward, data.X)
   local cpuMy = time(data.nIterations, myForward, data.X)

   return cpyNn, cpuMy
end
   
-- testForward: return cpu times for nIterations of each
-- check that results are identical
local function testForward(nnForward, myForward, data)
   local nnResult = nnForward(data.X)
   local myResult = myForward(data.X)
   printTensorValue('nnResult', nnResult)
   printTensorValue('myResult', myResult)
   assertEq(nnResult, myResult:t(), .0001)
   
   local cpuNn = time(data.nIterations, nnForward, data.X)
   local cpuMy = time(data.nIterations, myForward, data.X)

   return cpyNn, cpuMy
end

local function testLinearOLD()
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
end

local function test(data)
   local debug = true
   printTableValue('data', data)
   local function makeTheta(bias, weight)
      printTensorValue('bias', bias) printTensorValue('weight', weight)
      local theta = torch.Tensor(data.nClasses, data.nFeatures + 1)
      printTensorValue('theta', theta)
      for c = 1, data.nClasses do
         theta[c][1] = bias[c]
         for f = 1, data.nFeatures do
            theta[c][f + 1] = weight[c][f]
         end
      end
      return theta
   end

   local function testOne(name, driver, nnFunction, myFunction, data)
      local nnCpu, myCpu = driver(nnFunction, myFunction, data)
      print(string.format('cpu secs for %d iterations of %s: nn %f my %f',
                          data.nIterations, name, nnCpu, myCpu))
      return nnCpu, myCpu
   end

   local nnBias, nnWeight, nnLinear, nnForward = implementation7(data)
   -- augment data to include initial theta from the nn package's implementation
   data.theta = makeTheta(nnBias, nnWeight)

   local myLinear, myForward = implementation12(data)
   
   local nnLinear, myLinear = testOne('linear', testLinear, nnLinear, myLinear, data)
   local nnForward, myForward = testOne('forward', testForward, nnForward, myForward, data)
end

print('**************************************************************')
local data = makeData('small')
data.nIterations = 1000
test(data)
error('write more')
