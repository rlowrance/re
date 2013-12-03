-- ModelLogisticRegression.lua
-- logistic regression with multiple classes (multinomial logistic regression)

-- This code was abandoned before completion
print('WARNING: THIS MODULE HAS NOT BEEN UNIT TESTED')
print('THIS MODULE IS DEPRECATED. USE modelLogReg.lua INSTEAD'

require 'makeVp'
require 'nn'

-- API overview
if false then
   -- methods
   model = ModelLogisticRegression(nDimensions, nClasses, verbose)
   params = model:parameters()  -- TODO: also return gradWeights
   -- predict using current weights
   -- the most likely class is the index of the largest log probability
   logProbTensor = model:forward(input)
   -- derivate at current weights for last predicted input
   deriv = model:backward(input, gradOutput)
   model:zeroGradParameters()
   model:updateParameters(learningRate)
   model:print(optionalMsg)
   -- members
   o = model.output     -- last value returned by forward()
   g = model.gradInput  -- last value returned by backward()
end

local ModelLogisticRegression, parent = 
   torch.class('ModelLogisticRegression', 'nn.Module')
local verbose = 2
local vp = makeVp(verbose)
vp(3, 'ModelLogisticRegression', ModelLogisticRegression)
vp(3, 'parent', parent)  -- long printout

function ModelLogisticRegression:print(msg)
   local vp = makeVp(0)
   if msg ~= nil then
      vp(0, msg)
   end
   vp(0, 'ModelLogisticRegression', self)
   for k, v in pairs(self) do
      vp(0, ' .' .. k, v)
   end
   --vp(0, '.model[1]', self.model[1])
   --vp(0, '.model[2]', self.model[2])
   local weights, gradWeights = self:parameters()
   vp(0, 'weights', weights)
   for i, weight in ipairs(weights) do
      vp(0, 'weights[' .. i ..']', weights[i])
   end
   vp(0, 'gradWeights', gradWeights)
   for i, gradWeights in ipairs(weights) do
      vp(0, 'gradWeights[' .. i .. ']', gradWeights)
   end
end

function ModelLogisticRegression:__init(nDimensions, nClasses, verbose)
   -- follow the example nn.Linear
   local verbose = verbose or 0
   local vp, _, me = makeVp(verbose, 'ModelLogisticRegression:__init')
   vp(1, 'nDimensions', nDimensions)
   vp(1, 'nClasses', nClasses)

   parent.__init(self)

   local model = nn.Sequential()
   model:add(nn.Linear(nDimensions, nClasses))
   model:add(nn.LogSoftMax())

   self.model = model
   vp(1, 'self.model', self.model)
   

   if verbose >= 1 then self:print(me) end
   return self.model
end

function ModelLogisticRegression:parameters()
   return self.model:parameters()
end

-- provide implementation of method :forward(input)
function ModelLogisticRegression:updateOutput(input)
   local vp = makeVp(1, 'ModelLogisticRegression:updateOutput')
   vp(1, 'input', input)
   vp(1, 'weight', self.weights)
drummer813900   local result = self.model:updateOutput(input)
   vp(1, 'result', result)
   vp(1, 'output', self.output)
   stop()
   return result
end

-- provide 1st part of implemention of method :backward(input, gradOutput)
function ModelLogisticRegression:updateGradInput(input, gradOutput)
   local vp = makeVp(1, 'ModelLogisticRegression:updateGradInput')
   vp(1, 'input', input)
   vp(1, 'gradOutput', gradOutput)
   self.model:updateGradInput(input, gradOutput)
   vp(1, 'gradInput', gradInput)
end

-- provide 2nd part of implementation of method :backward(input, gradOutput)
function ModelLogisticRegression:accGradParameters(input, gradOutput, scale)
   local vp = makeVp(1, 'ModelLogisticRegression:accGradParameters')
   vp(1, 'input', input)
   vp(1, 'gradOutput', gradOutput)
   vp(1, 'scale', scale)
   self.model:accGradParameters(input, gradOutput, scale)
   vp(1, 'gradInput', gradInput)
end

ModelLogisticRegression.sharedAccUpdateGradParameters = 
   ModelLogisticRegression.accGradParameters

vp(1, 'ModelLogisticRegression', ModelLogisticRegression)
