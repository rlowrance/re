-- program_test_logreg_timing.lua
-- Determine how long multinomial logistic regression should run using various implementations
-- Use problem size typically of HEATING.CODE imputation:
--   k = 70
--   nClasses = 14

require 'assertEq'
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

-- implementation 8: Yann's LogregFprobBrpbo with 1 sample
local function makeLossGradient8(data)
   local vp = makeVp(1, 'makeLossGradient8')

   -- Yann's logistic regression training

   -- softmax of a vector
   local function softmax(x)
      local largest = torch.max(x)
      local e = torch.exp(x-largest)
      local z1 = 1/torch.sum(e)
      return e * z1
   end

   -- run logistic regression model on sample
   local function LogregFprop(x,theta)
      local s = torch.mv(theta,x)
      return softmax(s)
   end

   -- original code except commented lines are replaced with lines below them
   local function LogregFpropBprop(x,y,theta,L2) -- original used L3 instead of L2
      local s = torch.mv(theta,x)
      local p = softmax(s)
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      local target = torch.Tensor(theta:size(1)):zero()
      target[y] = 1
      --local gradient = torch.ger( (p[y] - target), x) - theta*L2
      local gradient = torch.ger( - (target - p[y]), x) - theta*L2  -- get == outer product
      return objective, gradient
   end

   -- original code except where commented out and possibly replaced
   local function LogregTrainSGD(X,Y,theta,L2,n,eta)
      local nsamples = X:size(1)
      local totalObjective = 0  -- added
      for i = 1, n do
         --sample = i % nsamples
         --local objective, gradient = LogregFpropBprop(X[sample],Y[sample],theta,L2)
         local objective, gradient = LogregFpropBprop(X[i],Y[i],theta,L2)
         torch.add(theta,-eta,gradient)
         totalObjective = totalObjective + objective
      end
      --return totalObjective/n, theta  
      return totalObjective/n, theta, gradient  -- NOTE: should return the averaged gradient, not the last gradient
   end

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   -- also compute theta after the SGD step
   local fakeTheta = torch.rand(14, 8)
   local L2 = 0
   local x = data.X[1]
   local y = data.y[1]
   local function lossGradient(theta)
      return LogregFpropBprop(x, y, fakeTheta, L2)
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 9: Yann's LogregFprobBrpbo with 70 samples
-- Other incrmemental functionality that could be added
-- - take logs, because that's what package nn does
-- - ravel and unravel the theta argument. It should be flat, but its structured in Yann's code.
-- - compute average loss and average gradient for the sample. My implementation does this.
local function makeLossGradient9(data)
   local vp = makeVp(1, 'makeLossGradient8')

   -- Yann's logistic regression training

   -- softmax of a vector
   local function softmax(x)
      local largest = torch.max(x)
      local e = torch.exp(x-largest)
      local z1 = 1/torch.sum(e)
      return e * z1
   end

   -- run logistic regression model on sample
   local function LogregFprop(x,theta)
      local s = torch.mv(theta,x)
      return softmax(s)
   end

   -- original code except commented lines are replaced with lines below them
   local function LogregFpropBprop(x,y,theta,L2) -- original used L3 instead of L2
      local s = torch.mv(theta,x)
      local p = softmax(s)
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      local target = torch.Tensor(theta:size(1)):zero()
      target[y] = 1
      --local gradient = torch.ger( (p[y] - target), x) - theta*L2
      local gradient = torch.ger( - (target - p[y]), x) - theta*L2
      return objective, gradient
   end

   -- original code except where commented out and possibly replaced
   local function LogregTrainSGD(X,Y,theta,L2,n,eta)
      local nsamples = X:size(1)
      local totalObjective = 0  -- added
      for i = 1, n do
         --sample = i % nsamples
         --local objective, gradient = LogregFpropBprop(X[sample],Y[sample],theta,L2)
         local objective, gradient = LogregFpropBprop(X[i],Y[i],theta,L2)
         torch.add(theta,-eta,gradient)
         totalObjective = totalObjective + objective
      end
      --return totalObjective/n, theta  
      return totalObjective/n, theta, gradient  -- NOTE: should return the averaged gradient, not the last gradient
   end

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   -- also compute theta after the SGD step
   local fakeTheta = torch.rand(14, 8)
   local L2 = 0
   local x = data.X[1]
   local y = data.y[1]
   local nSamples = data.X:size(1)
   print('nSamples', nSamples)
   local function lossGradient(theta)
      local loss, gradient
      for sampleIndex = 1, nSamples do
         loss, gradient =  LogregFpropBprop(x, y, fakeTheta, L2)
      end
      return loss, gradient
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 10: Yann's LogregFprobBrpbo with 70 sample and logs
local function makeLossGradient10(data)
   local vp = makeVp(1, 'makeLossGradient8')

   -- Yann's logistic regression training

   -- softmax of a vector
   local function softmax(x)
      local largest = torch.max(x)
      local e = torch.exp(x-largest)
      local z1 = 1/torch.sum(e)
      return e * z1
   end

   -- run logistic regression model on sample
   local function LogregFprop(x,theta)
      local s = torch.mv(theta,x)
      return softmax(s)
   end

   -- original code except commented lines are replaced with lines below them
   local function LogregFpropBprop(x,y,theta,L2) -- original used L3 instead of L2
      local s = torch.mv(theta,x)
      local p = softmax(s)
      local pLog = torch.log(p) -- simulate NLL instead of softmax
      local pExpLog = torch.exp(pLog)
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      local target = torch.Tensor(theta:size(1)):zero()
      target[y] = 1
      --local gradient = torch.ger( (p[y] - target), x) - theta*L2
      local gradient = torch.ger( - (target - p[y]), x) - theta*L2
      return objective, gradient
   end

   -- original code except where commented out and possibly replaced
   local function LogregTrainSGD(X,Y,theta,L2,n,eta)
      local nsamples = X:size(1)
      local totalObjective = 0  -- added
      for i = 1, n do
         --sample = i % nsamples
         --local objective, gradient = LogregFpropBprop(X[sample],Y[sample],theta,L2)
         local objective, gradient = LogregFpropBprop(X[i],Y[i],theta,L2)
         torch.add(theta,-eta,gradient)
         totalObjective = totalObjective + objective
      end
      --return totalObjective/n, theta  
      return totalObjective/n, theta, gradient  -- NOTE: should return the averaged gradient, not the last gradient
   end

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   -- also compute theta after the SGD step
   local fakeTheta = torch.rand(14, 8)
   local L2 = 0
   local x = data.X[1]
   local y = data.y[1]
   local nSamples = data.X:size(1)
   local function lossGradient(theta)
      local loss, gradient
      for sampleIndex = 1, nSamples do
         loss, gradient =  LogregFpropBprop(x, y, fakeTheta, L2)
      end
      return loss, gradient
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end

-- implementation 11: Yann's LogregFprobBrpbo add: ravel and deravel theta
local function makeLossGradient11(data)
   local vp = makeVp(1, 'makeLossGradient11')

   -- Yann's logistic regression training

   -- softmax of a vector
   local function softmax(x)
      local largest = torch.max(x)
      local e = torch.exp(x-largest)
      local z1 = 1/torch.sum(e)
      return e * z1
   end

   -- run logistic regression model on sample
   local function LogregFprop(x,theta)
      local s = torch.mv(theta,x)
      return softmax(s)
   end

   -- original code except commented lines are replaced with lines below them
   local function LogregFpropBprop(x,y,theta,L2) -- original used L3 instead of L2
      local s = torch.mv(theta,x)
      local p = softmax(s)
      local pLog = torch.log(p) -- simulate NLL instead of softmax
      local pExpLog = torch.exp(pLog)
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      local target = torch.Tensor(theta:size(1)):zero()
      target[y] = 1
      --local gradient = torch.ger( (p[y] - target), x) - theta*L2
      local gradient = torch.ger( - (target - p[y]), x) - theta*L2
      return objective, gradient -- NOTE: should ravel the gradient
   end

   -- original code except where commented out and possibly replaced
   local function LogregTrainSGD(X,Y,theta,L2,n,eta)
      local nsamples = X:size(1)
      local totalObjective = 0  -- added
      for i = 1, n do
         --sample = i % nsamples
         --local objective, gradient = LogregFpropBprop(X[sample],Y[sample],theta,L2)
         local objective, gradient = LogregFpropBprop(X[i],Y[i],theta,L2)
         torch.add(theta,-eta,gradient)
         totalObjective = totalObjective + objective
      end
      --return totalObjective/n, theta  
      return totalObjective/n, theta, gradient  -- NOTE: should return the averaged gradient, not the last gradient
   end

   -- return loss and gradient wrt parameters
   -- using all the data as a mini batch
   -- also compute theta after the SGD step
   local nClasses = data.nClasses
   local nSamples = data.X:size(1)
   local nFeatures = data.X:size(2)

   local fakeTheta = torch.rand(nClasses, nFeatures)
   local L2 = 0
   local x = data.X[1]
   local y = data.y[1]
   local bias = torch.Tensor(nClasses)
   local weight = torch.Tensor(nClasses, nFeatures)
   local flatGradient = torch.Tensor(nClasses * nFeatures)

   local function lossGradient(theta)
      --assert(theta:nDimension() == 1)
      -- theta is 2D
      -- fake de-raveling of theta
      for c = 1, nClasses do
         local first = 1 + (c - 1) * nFeatures
         bias[c] = theta[c] -- bias isn't handled in the LogregFpropBprop, so fake it
         weight[c] = theta:sub(first, first + nFeatures - 1)
      end
      -- a real LogregFpropBprop would use bias and weights
      --local sumLosses = 0
      --local sumGradients = torch.Tensor(nClasses, nFeatures):zero()
      local loss, gradient
      for sampleIndex = 1, nSamples do
         loss, gradient =  LogregFpropBprop(x, y, fakeTheta, L2)
         --sumLosses = sumLosses + loss
         --sumGradient = sumGradient + gradient
      end
      -- ravel (flatten) the gradient
      --local flatGradient = torch.Tensor(gradient)
      local flatGradient = torch.Tensor(gradient:storage(), 1, gradient:nElement(), 1)
      --return sumLosses, flatGradient  -- no need to average
      return loss, flatGradient
   end

   return lossGradient, (data.nFeatures + 1) * data.nClasses
end


-- implementation 12: Yann's idea in batch mode
local function makeLossGradient12(data)
   local vp = makeVp(1, 'makeLossGradient11')

   local nClasses = data.nClasses
   local nSamples = data.X:size(1)
   local nFeatures = data.X:size(2)

   local oneNClasses = torch.Tensor(nClasses):fill(1)

   -- Yann's logistic regression training updated to handle X (matrix) instead of x (vector)

   -- softmax of a matrix considered row by row
   local function softmax(X)
      -- original code for when x is a vector
--    local largest = torch.max(x)
--    local e = torch.exp(x-largest)
--    local z1 = 1/torch.sum(e)
--    return e * z1

      assert(X:size(1) == nClasses and X:size(2) == nSamples)

      -- local largest = torch.max(x)
      local largestVector = torch.max(X,2)  -- size nClasses x 1
      if false then
         assert(largestVector:nDimension() == 2 and largestVector:size(1) == nClasses and largestVector:size(2) == 1)
         local largestVector2 = largestVector:select(2, 1) -- drop the last dimension and copy storage
         local largestMatrix2 = torch.Tensor(largestVector2:storage(), 1, nClasses, 1, nSamples, 0)
      end
      if true then
         local largestMatrix = torch.Tensor(largestVector:storage(), 1, nClasses, 1, nSamples, 0)
         assert(largestMatrix:nDimension() == 2 and
                largestMatrix:size(1) == nClasses and 
                largestMatrix:size(2) == nSamples)
         local temp = X - largestMatrix -- throws with 'inconsistent tensor size'
      end
      local largestMatrix = torch.Tensor(largestVector:storage(), 1, nClasses, 1, nSamples, 0)
      assert(largestMatrix:nDimension() == 2 and
             largestMatrix:size(1) == nClasses and 
             largestMatrix:size(2) == nSamples)
      local temp = X - largestMatrix -- throws with 'inconsistent tensor size'

      -- local e = torch.exp(x - largest)
      local e = torch.exp(X-largestMatrix) -- of size nClasses x nSamples

      --local z1 = 1/torch.sum(e)
      --z1 is the normalizer for the probabilities
      local sum = torch.sum(e,2)  -- sum is size nClasses x 1
      local sumVector = torch.Tensor(sum:storage(), 1, nClasses, 1)
      local z1Vector = torch.cdiv(oneNClasses, sumVector) -- z1 is size nClasses
      local z1Matrix = torch.Tensor(z1Vector:storage(), 1, nClasses, 1, nSamples, 0)

      -- return e * z1
      return torch.cmul(e, z1Matrix)
   end

   

   -- original code except commented lines are replaced with lines below them
   local function LogregFpropBprop(X,y,theta,L2) -- original used L3 instead of L2
      assert(X:nDimension() == 2)
      -- local s = torch.mv(theta, x)
      local s = torch.mm(theta, X:t()) -- s is nClasses x nSamples
      local p = softmax(s)             -- p is nClasses x nSamples
      if true then 
         local sum = 0
         for rowIndex = 1, p:size(1) do 
            local sum = 0
            for colIndex = 1, p:size(2) do
               sum = sum + p[rowIndex][colIndex]
            end
            assertEq(sum, 1, .0001)
         end
      end
      if true then return end
      --local objective = -log(p[y])
      local objective = -math.log(p[y])
      local target = torch.Tensor(theta:size(1)):zero()
      target[y] = 1
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
         print('starting implementation', i)
         local cpu, wallclock = timeCalls(data, implementation.maker, config.nIterations)
         times[i] = {cpu = cpu, wallclock = wallclock}
      end
   end

   -- print comparison of execution times
   --printTableValue('times', times)
   print()
   print(ifelse(jit, '', 'not ') .. 'using luajit')
   print(string.format('timings in seconds per iterations over %d iterations', config.nIterations))
   print(string.format('   implementation %25s %8s       %%1 %8s %%1', ' ', 'cpu', 'wallclock'))
   local cpu1 = times[1].cpu
   local wallclock1 = times[1].wallclock
   cpu1 = ifelse(cpu1 == nil, 0, cpu1)
   wallclock1 = ifelse(wallclock1 == nil, 0, wallclock1)
   for i, time in pairs(times) do
      print(string.format('%2d %45s %8.6f %3.0f %8.6f %3.0f', 
                           i, 
                           implementations[i].description, 
                           time.cpu / config.nIterations, 
                           time.cpu / cpu1 * 100,
                           time.wallclock / config.nIterations,
                           time.wallclock / wallclock1 * 100))
   end
end

-- build table of all the implementations
local function makeImplementations()
   local result = {}

   local function implementation(index, maker, description)
      result[index] = {maker = maker, description = description}
   end

   implementation(1, makeLossGradient1, 'original')
   implementation(2, makeLossGradient2, 'remove makeVp')
   implementation(3, makeLossGradient3, 'move getParameters out of function call')
   implementation(4, makeLossGradient4, 'require theta == parameters')
   implementation(5, makeLossGradient5, 'unroll + only gradOutput')
   implementation(6, makeLossGradient6, 'just gradParameters')
   implementation(7, makeLossGradient7, '2 + 3 + 6')
   implementation(8, makeLossGradient8, 'Yann original-1 sample')
   implementation(9, makeLossGradient9, 'Yann add 70 samples')
   implementation(10, makeLossGradient10, 'Yann add logs')
   implementation(11, makeLossGradient11, 'Yann add theta raveling, unraveling')
   implementation(12, makeLossGradient12, 'Yann batch just softmax')

   return result
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
   nIterations = 100,
   nIterations = 1000,
   --nIterations = 1, 
   --nIterations = 1000,
   compareImplementations = true,
   nSamples = 70,
   nFeatures = 8,
   nClasses = 14, 
}

printTableValue('config', config)


-- define implementatins
local implementations = makeImplementations()
printTableValue('implementations', implementations)

-- create data
local data = makeData(config.nClasses, config.nFeatures, config.nSamples)
printTableValue('data', data)

-- compare timings
if config.compareImplementations then
   print('comparing implementations')
   compareImplementations(config, data, implementations)
end

print('done')
