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

   -- construct new LogregOpfuncNnBatch for use in predictions
   local nSamples = newX:size(1)
   local newY = torch.Tensor(nSamples):fill(1)  -- set class arbitrarily to 1
   local newS = torch.Tensor(nSamples):fill(1)  -- saliences are all one
   local newOpfunc = LogRegOpfuncNnBatch(newX, newY, newS, self.nClasses, self.lambda)
   local loss, gradient, logProbabilities = newOpfunc:_lossGradientPredictions(theta)
   assert(logProbabilities:size(1) == nSamples)
   assert(logProbabilities:size(2) == self.nClasses)
   return torch.exp(logProbabilities)
end
