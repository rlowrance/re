-- LogregOpfuncNnOne.lua
-- logistic regression opfunc using nn package and 
-- stochastic loss and gradient and a random sample

require 'argmax'
require 'assertEq'
require 'checkGradient'
require 'keyboard'
require 'LogregOpfunc'
require 'makeNextPermutedIndex'
require 'makeVp'
require 'memoryUsed'
require 'nn'
require 'printAllVariables'
require 'printTableVariable'
require 'sgdBottouDriver'
require 'Timer'
require 'torch'
require 'unique'
require 'validateAttributes'

-- CONSTRUCTOR

local LogregOpfuncNnOne, parent = torch.class('LogregOpfuncNnOne', 'LogregOpfunc')

function LogregOpfuncNnOne:__init(X, y, s, nClasses, lambda)
   parent.__init(self, X, y, s, nClasses, lambda)

   -- define unregularized model
   -- make modules within model explicit for testing purposes
   self.model = nn.Sequential()
   self.linear = nn.Linear(self.nFeatures, self.nClasses)
   self.logsoftmax = nn.LogSoftMax()
   self.model:add(self.linear)
   self.model:add(self.logsoftmax)  -- be sure to call the constructor!
   
   -- couple and flatten parameters and gradient
   -- the only parameters are in the linear module
   self.modelTheta, self.modelGradient = self.model:getParameters()

   -- define optimization criterion
   self.criterion = nn.ClassNLLCriterion()

   -- save initial parameters that were set by the Linear() constructor
   -- NOTE: self.initialTheta is a function defined in the parent class!
   self.initialThetaValue = self.modelTheta:clone()
   
   -- build table of randomly-permuted values
   self.randPermutationIndices = torch.randperm(self.nSamples)
   self.nextRandomIndex = 0

   --printTableVariable('self')
end

-- PUBLIC METHODS

-- return flat parameters that are a suitable starting point for optimization
-- RETURNS
-- theta : Tensor 1D
function LogregOpfuncNnOne:runInitialTheta()
   return self.initialThetaValue
end

-- return gradient at same parameters as lost call to loss method
-- ARGS
-- lossInfo : table from the loss methods
-- RETURNS
-- gradient : Tensor !D
function LogregOpfuncNnOne:runGradient(lossInfo)
   local vp = makeVp(0, ':runGradient')
   --printTableVariable('lossInfo')
   vp(1, 'lossInfo', lossInfo)
   return lossInfo.gradient
end

-- return loss at randomly-chosen sample and secret values that can compute gradient quickly
-- ARGS
-- theta    : Tensor 1D, parameters
-- RETURNS
-- loss     : number at next randomly-selected X, y, s sample
-- lossInfo : table with secret content
function LogregOpfuncNnOne:runLoss(theta)
   local vp = makeVp(0, ':runLoss')
   self.nextRandomIndex = self.nextRandomIndex + 1
   if self.nextRandomIndex > self.nSamples then
      self.nextRandomIndex = 1
   end

   local loss, gradient = self:_lossGradient(theta, self.nextRandomIndex)
   vp(2, 'loss', loss, 'gradient', gradient)
   assert(loss)
   assert(gradient)

   return loss, {gradient = gradient, i = self.nextRandomIndex}
end

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

-- compute regularized loss and gradient all at once
-- ref: torch/cogbits.com/doc/tutorials_supervised/
function LogregOpfuncNnOne:_lossGradient(theta, sampleIndex)

   if self.modelTheta ~= theta then
      self.modelTheta:copy(theta)
   end

   local input = self.X[sampleIndex]
   local target = self.y[sampleIndex]
   local importance = self.s[sampleIndex]

   -- compute loss
   local loss = self.criterion(self.model:forward(input), target) * importance

   -- regularize loss
   local weights = self.linear.weight
   local regularizer = torch.sum(torch.cmul(weights, weights))
   local lossRegularized = loss + self.lambda * regularizer

   -- compute gradient into self.modelGradient
   self.model:zeroGradParameters()
   self.model:backward(input, self.criterion:backward(self.model.output, target) * importance)

   -- regularize gradient; retain earlier slower versions as documentation
   local gradientRegularized = nil
   local gradientRegularizedVersion1 = nil
   local gradientRegularziedVersion2 = nil
   local gradientVersion = 2
   if gradientVersion == 1 or gradientVersion == 'all' then
      gradientRegularized1 = self.modelGradient:clone()
      local index = 0
      for c = 1, self.nClasses do
         for d = 1, self.nFeatures do
            index = index + 1
            gradientRegularized1[index] = 
            gradientRegularized1[index] + 2 * self.lambda * weights[c][d]
         end
      end
      gradientRegularized = gradientRegularized1
   elseif gradientVersion == 2 or gradientVersion == 'all' then
      gradientRegularized2 = self.modelGradient:clone()
      local weightsGradient = torch.Tensor(gradientRegularized2:storage(), 1, weights:nElement(), 1)
      local weightsGradient1 = weightsGradient + (weights * 2 * self.lambda)
      torch.add(weightsGradient, weightsGradient, 2 * self.lambda, weights)
      gradientRegularized = gradientRegularized2
   end
   if gradientVersion == 'both' then
      assertEq(gradientRegularizedVersion1, gradientRegularizedVersion2, .0001)
   end

   return lossRegularized, gradientRegularized
end

