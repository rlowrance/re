-- LogregOpfuncNnBatch.lua
-- logistic regression opfunc using nn package and 
-- loss and gradient over the entire epoch (called a batch in this code)

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

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local LogregOpfuncNnBatch, parent = torch.class('LogregOpfuncNnBatch', 'LogregOpfunc')

function LogregOpfuncNnBatch:__init(X, y, s, nClasses, lambda)
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
   
   -- build table of randomly-permuted sample indices
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
function LogregOpfuncNnBatch:runInitialTheta()
   return self.initialThetaValue
end

-- return gradient at same parameters as lost call to loss method
-- ARGS
-- lossInfo : table from the loss method
-- RETURNS
-- gradient : Tensor !D
function LogregOpfuncNnBatch:runGradient(lossInfo)
   return lossInfo.gradient
end

-- return loss at randomly-chosen sample and secret values that can compute gradient quickly
-- ARGS
-- theta    : Tensor 1D, parameters
-- RETURNS
-- loss     : number at next randomly-selected X, y, s sample
-- lossInfo : table with secret content
function LogregOpfuncNnBatch:runLoss(theta)
   assert(theta ~= nil, 'theta not supplied')
   assert(theta:nDimension() == 1, 'theta is not a 1D Tensor')

   local loss, gradient = self:_lossGradientPredictions(theta)
   assert(loss)
   assert(gradient)

   return loss, {gradient = gradient}
end

-- return predictions at newX matrix using specified theta
-- ARGS
-- newX           : 2D Tensor of new samples
-- theta          : 1D Tensor
-- RETURNS
-- probabilities  : 2D Tensor of probabilities
function LogregOpfuncNnBatch:predict(newX, theta)
   assert(newX:nDimension() == 2, 'newX is not a 2D Tensor')
   assert(newX:size(2) == self.X:size(2), 'newX has wrong number of features')

   -- avoid construction of a new LogregOpfuncNnBatch by replacing and restoring field X
   if true then
      local currentX = self.X
      self.X = newX
      local _, _, logProbabilities = self:_lossGradientPredictions(theta)
      local probabilities = torch.exp(logProbabilities)
      self.X = currentX  -- restore field X
      return probabilities
   end
end
   


-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

-- compute regularized loss and gradient and predictions for all samples
-- ref: torch/cogbits.com/doc/tutorials_supervised/
-- ARGS
-- theta          : 1D Tensor of parameters
-- RETURNS
-- loss           : number
-- gradient       ; 1D Tensor with same shape as theta
-- logProbabilies : 1D Tensor of size self.nClasses
function LogregOpfuncNnBatch:_lossGradientPredictions(theta)
   local vp, verboseLevel = makeVp(0, 'LogregOpfuncNnBatch:_lossGradientPredictions')
   local v = verboseLevel > 0
   if v then
      vp(1, 'theta', theta, 'self', self)
      printTableVariable('self')
   end
   assert(type(self.lambda) == 'number', 'lambda=' .. tostring(lambda))

   if self.modelTheta ~= theta then
      self.modelTheta:copy(theta)
   end

   -- compute loss for all samples, which for one sample was
   -- local loss = self.criterion(self.model:forward(input), target) * importance
   local logProbabilities = self.model:forward(self.X)
   local s2d = torch.Tensor(self.s:storage(), 1, self.nSamples, 1, self.nClasses, 0)
   local weightedLogPredictions = torch.cmul(logProbabilities, s2d)
   vp(2, 'logProbabilities', logProbabilities, 'self.s', self.s)
   vp(2, 'weightedLogPredictions', weightedLogPredictions, 'self.y', self.y)
   local loss = self.criterion(weightedLogPredictions, self.y)
   if v and false then
      vp(2, 'X', self.X)
      vp(2, 'scores', self.linear.output)
      vp(2, 'logProbabilities', logProbabilities)
      vp(2, 's', self.s, 's2d', s2d)
      vp(2, 'weightedLogPredictions', weightedLogPredictions)
      vp(2, 'loss', loss)
   end

   -- regularize loss
   local weights = self.linear.weight
   local regularizer = torch.sum(torch.cmul(weights, weights))
   if v then
      vp(2, 'weights', weights)
      vp(2, 'regularizer', regularizer)
      vp(2, 'self.lambda', self.lambda)
   end
   local lossRegularized = loss + self.lambda * regularizer


   -- compute gradient into self.modelGradient
   self.model:zeroGradParameters()
   --self.model:backward(input, self.criterion:backward(self.model.output, target) * importance)
   local gradientCriterionUnweighted = self.criterion:backward(self.model.output, self.y) 
   local gradientCriterionWeighted = torch.cmul(gradientCriterionUnweighted, s2d)
   self.model:backward(self.X, gradientCriterionWeighted)
   if v then
      vp(2, 'gradientCriterionUnweighted', gradientCriterionUnweighted)
      vp(2, 'gradientCriterionWeighted', gradientCriterionWeighted)
      vp(2, 'modelGradient', self.modelGradient)
   end

   -- regularize gradient; retain earlier slower versions as documentation
   if v then
      vp(3, 'self.modelGradient', self.modelGradient, 'weights', weights)
   end

   -- during development, we first coded version 1 and then parallelized it to get version 2
   -- version 2 is faster
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
   if gradientVersion == 'all' then
      assertEq(gradientRegularizedVersion1, gradientRegularizedVersion2, .0001)
   end

   return lossRegularized, gradientRegularized, logProbabilities
end



   

   
   
