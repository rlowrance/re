-- ObjectivefunctionLogregNnbatch.lua
-- logistic regression opfunc using nn package and 
-- loss and gradient over the entire epoch (called a batch in this code)

require 'argmax'
require 'assertEq'
require 'checkGradient'
require 'keyboard'
require 'ObjectivefunctionLogreg'
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

local ObjectivefunctionLogregNnbatch, parent = torch.class('ObjectivefunctionLogregNnbatch', 'ObjectivefunctionLogreg')

function ObjectivefunctionLogregNnbatch:__init(X, y, s, nClasses, L2)
   parent.__init(self, X, y, s, nClasses, L2)

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
-- theta : Tensor 1D of flat parameters
function ObjectivefunctionLogregNnbatch:runrunInitialTheta()
   return self.initialThetaValue
end

-- return gradient at same parameters as lost call to loss method
-- ARGS
-- theta : Tensor 1D of flat parameters
-- RETURNS
-- gradient : Tensor !D
function ObjectivefunctionLogregNnbatch:runrunGradient(theta)
   local gradient, _, _ = self:_gradientLossLogprobabilities(theta)
   return gradient
end

-- return loss at randomly-chosen sample and secret values that can compute gradient quickly
-- ARGS
-- theta    : Tensor 1D, parameters
-- RETURNS
-- loss     : number at next randomly-selected X, y, s sample
function ObjectivefunctionLogregNnbatch:runrunLoss(theta)
   assert(theta ~= nil, 'theta not supplied')
   assert(theta:nDimension() == 1, 'theta is not a 1D Tensor')

   local loss, _ = self:_lossLogprobabilities(theta)
   assert(loss)

   return loss
end

function ObjectivefunctionLogregNnbatch:runrunLossGradient(theta)
   assert(theta ~= nil, 'theta not supplied')
   assert(theta:nDimension() == 1, 'theta is not a 1D Tensor')

   local gradient, loss, _ = self:_gradientLossLogprobabilities(theta)
   assert(loss)
   assert(gradient)

   return loss, gradient
end

-- return predictions at newX matrix using specified theta
-- ARGS
-- newX           : 2D Tensor of new samples
-- theta          : 1D Tensor
-- RETURNS
-- probabilities  : 2D Tensor of probabilities
function ObjectivefunctionLogregNnbatch:runrunPredictions(newX, theta)
   assert(newX:nDimension() == 2, 'newX is not a 2D Tensor')
   assert(newX:size(2) == self.X:size(2), 'newX has wrong number of features')

   -- avoid construction of a new ObjectivefunctionLogregNnbatch by replacing and restoring field X
   local currentX = self.X  -- save field X
   self.X = newX
   local logProbabilities = self:_logprobabilities(theta)
   local probabilities = torch.exp(logProbabilities)
   self.X = currentX  -- restore field X
   return probabilities
end
   


-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

-- RETURNS
-- logProbabililites : 2D Tensor
function ObjectivefunctionLogregNnbatch:_logprobabilities(theta)
   if self.modelTheta ~= theta then
      self.modelTheta:copy(theta)
   end

   local logProbabilities = self.model:forward(self.X)
   
   return logProbabilities
end

-- RETURNS
-- loss             : number, regularized loss
-- logProbabilities : 2D Tensor
function ObjectivefunctionLogregNnbatch:_lossLogprobabilities(theta)
   local vp, verboseLevel = makeVp(0, 'ObjectivefunctionLogregNnbatch:_lossLogprobabilities')
   local v = verboseLevel > 0

   local logProbabilities = self:_logprobabilities(theta)

   -- compute loss for all samples, which for one sample was
   -- local loss = self.criterion(self.model:forward(input), target) * importance
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
      vp(2, 'self.L2', self.L2)
   end
   local lossRegularized = loss + self.L2 * regularizer

   return lossRegularized, logProbabilities
end

-- compute regularized loss and gradient and predictions for all samples
-- ref: torch/cogbits.com/doc/tutorials_supervised/
-- ARGS
-- theta          : 1D Tensor of parameters
-- RETURNS
-- gradientRegularized ; 1D Tensor with same shape as theta
-- lossRegularized     : number
-- logProbabilies      : 1D Tensor of size self.nClasses
function ObjectivefunctionLogregNnbatch:_gradientLossLogprobabilities(theta)
   local vp, verboseLevel = makeVp(0, 'ObjectivefunctionLogregNnbatch:_lossGradientPredictions')
   local v = verboseLevel > 0
   if v then
      vp(1, 'theta', theta, 'self', self)
      printTableVariable('self')
   end
   assert(type(self.L2) == 'number', 'L2=' .. tostring(L2))

   local lossRegularized, logProbabilities = self:_lossLogprobabilities(theta)
   vp(2, 'lossRegularized', lossRegularized, 'logProbabilities', logProbabilities)


   -- compute gradient into self.modelGradient
   self.model:zeroGradParameters()
   --self.model:backward(input, self.criterion:backward(self.model.output, target) * importance)
   local gradientCriterionUnweighted = self.criterion:backward(self.model.output, self.y) 
   local s2d = torch.Tensor(self.s:storage(), 1, self.nSamples, 1, self.nClasses, 0)
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
   local weights = self.linear.weight
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
            gradientRegularized1[index] + 2 * self.L2 * weights[c][d]
         end
      end
      gradientRegularized = gradientRegularized1
   elseif gradientVersion == 2 or gradientVersion == 'all' then
      gradientRegularized2 = self.modelGradient:clone()
      local weightsGradient = torch.Tensor(gradientRegularized2:storage(), 1, weights:nElement(), 1)
      local weightsGradient1 = weightsGradient + (weights * 2 * self.L2)
      torch.add(weightsGradient, weightsGradient, 2 * self.L2, weights)
      gradientRegularized = gradientRegularized2
   end
   if gradientVersion == 'all' then
      assertEq(gradientRegularizedVersion1, gradientRegularizedVersion2, .0001)
   end

   return gradientRegularized, lossRegularized,  logProbabilities
end



   

   
   
