-- OpfuncLogregNnOne.lua
-- logistic regression opfunc using nn package and 
-- stochastic loss and gradient and a random sample

require 'argmax'
require 'assertEq'
require 'checkGradient'
require 'keyboard'
require 'OpfuncLogreg'
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

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local OpfuncLogregNnOne, parent = torch.class('OpfuncLogregNnOne', 'OpfuncLogreg')

function OpfuncLogregNnOne:__init(X, y, s, nClasses, lambda)
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

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return flat parameters that are a suitable starting point for optimization
-- RETURNS
-- theta : Tensor 1D
function OpfuncLogregNnOne:runrunInitialTheta()
   return self.initialThetaValue
end

-- return gradient at same parameters as lost call to loss method
-- ARGS
-- theta    : 1D Tensor of flat parameters
-- RETURNS
-- gradient : Tensor !D
function OpfuncLogregNnOne:runrunGradient(theta)
   local vp = makeVp(0, ':runrunGradient')
   --printTableVariable('lossInfo')
   local gradient = of:_gradientLossLogprobabilities(theta)
   return gradient
end

-- return loss at randomly-chosen sample and secret values that can compute gradient quickly
-- ARGS
-- theta    : Tensor 1D, parameters
-- RETURNS
-- loss     : number at next randomly-selected X, y, s sample
function OpfuncLogregNnOne:runrunLoss(theta)
   local vp = makeVp(0, ':runrunLoss')
   self.nextRandomIndex = self.nextRandomIndex + 1
   if self.nextRandomIndex > self.nSamples then
      self.nextRandomIndex = 1
   end

   local loss, _ = self:_lossLogprobabilities(theta, self.nextRandomIndex)
   assert(loss)

   return loss
end

-- return loss and gradient at random sample using specified parameters
-- ARGS
-- theta    : Tensor 1D, flat parameters
-- RETURNS
-- loss     : number
-- gradient : 1D Tensor
function OpfuncLogregNnOne:runrunLossGradient(theta)
   self.nextRandomIndex = self.nextRandomIndex + 1
   if self.nextRandomIndex > self.nSamples then
      self.nextRandomIndex = 1
   end

   local gradient, loss, _ = self:_gradientLossLogprobabilities(theta, self.nextRandomIndex)
   assert(loss)
   assert(gradient)

   return loss, gradient
end

-- return predictions at points X using specified parameters
-- ARGS
-- newX  : 2D Tensor of features
-- theta : 1D Tensor of flat parameters
-- RETURNS
-- probabilities : 2D Tensor with probabilities of classes
function OpfuncLogregNnOne:runrunPredictions(newX, theta)
   assert(newX:nDimension() == 2)
   assert(theta:nDimension() == 1)

   error('not implemented')
end

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

-- return log probabilities
function OpfuncLogregNnOne:_logProbabilities(theta, sampleIndex)
   assert(theta:nDimension() == 1)
   assert(type(sampleIndex) == 'number')
   assert(sampleIndex > 0)

   if self.modelTheta ~= theta then
      self.modelTheta:copy(theta)
   end

   local input = self.X[sampleIndex]
   
   local logProbabilities = self.model:forward(input)
   return logProbabilities
end

-- return loss and logProbabilities
function OpfuncLogregNnOne:_lossLogprobabilities(theta, sampleIndex)
   if self.modelTheta ~= theta then
      self.modelTheta:copy(theta)
   end

   local input = self.X[sampleIndex]
   local target = self.y[sampleIndex]
   local importance = self.s[sampleIndex]

   -- compute loss
   local logProbabilities = self:_logProbabilities(theta, sampleIndex)
   local loss = self.criterion(logProbabilities, target) * importance

   -- regularize loss
   local weights = self.linear.weight
   local regularizer = torch.sum(torch.cmul(weights, weights))
   local lossRegularized = loss + self.lambda * regularizer

   return lossRegularized, logProbabilities
end


-- compute regularized loss and gradient all at once
-- ref: torch/cogbits.com/doc/tutorials_supervised/
function OpfuncLogregNnOne:_gradientLossLogprobabilities(theta, sampleIndex)
   local lossRegularized, logProbabilities = self:_lossLogprobabilities(theta, sampleIndex)
   assert(lossRegularized)
   assert(logProbabilities)


   local input = self.X[sampleIndex]
   local target = self.y[sampleIndex]
   local importance = self.s[sampleIndex]

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
      local weights = self.linear.weight
      local weightsGradient = torch.Tensor(gradientRegularized2:storage(), 1, weights:nElement(), 1)
      local weightsGradient1 = weightsGradient + (weights * 2 * self.lambda)
      torch.add(weightsGradient, weightsGradient, 2 * self.lambda, weights)
      gradientRegularized = gradientRegularized2
   end
   if gradientVersion == 'both' then
      assertEq(gradientRegularizedVersion1, gradientRegularizedVersion2, .0001)
   end

   return gradientRegularized, lossRegularized, logProbabilities
end

