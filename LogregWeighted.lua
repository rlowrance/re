-- LogregWeighted.lua
-- abstract class for regularized weighted logistic regression

if false then
   -- API overview
   model = LogregWeightedSUBCLASS(X, y, s, nClasses, lambda)
   optimalTheta, fitInfo = model:fit(fittingOptions)
   
   -- prediction using the optimal theta or any theta
   probs, class = model:predict(newX1D, theta)    -- returns number of the predicted class
   probs, classes = model:predict(newX2D, theta)  -- returns 1D Tensor of predicted classes
end

require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local logregWeighted = torch.class('LogregWeighted')

function LogregWeighted:__init(X, y, s, nClasses, lambda)
   -- validate arguments
   assert(X, 'X not supplied')
   assert(X:nDimension() == 2, 'X is not a 2D Tensor')
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)

   assert(y, 'y not supplied')
   assert(y:nDimension() == 1, 'y is not a 1D Tensor')
   assert(y:size(1) == self.nSamples, 'y size is invalid')

   assert(s, 's not supplied')
   assert(s:nDimension() == 1, 's is not a 1D Tensor')
   assert(s:size(1) == self.nSamples, 's size is invalid')

   assert(nClasses, 'nClasses not supplied')
   assert(type(nClasses) == 'number', 'nClasses is not a number')

   assert(lambda, 'lambda not supplied')
   assert(type(lambda) == 'number', 'lambda is not a number')
   assert(lambda >= 0, 'lambda not non-negative')

   -- save args
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- ARGS:
-- fittingOptions : unexamined, depends on concrete subclass
-- RETURNS:
-- optimalTheta : 1D Tensor of optimal parameters relative to fittingOptions
-- fitInfo      : table, content depends on concrete subclass  
function LogregWeighted:fit(fittingOptions)
   return self:runFit(fittingOptions)
end

-- ARGS
-- newX       : 1D Tensor or 2D Tensor
-- RETURNS
-- probs      : 1D or 2D Tensor of probabilities for each class
--              probs:size(2) == nClasses
-- prediction : number or 1D Tensor or class numbers
function LogregWeighted:predict(newX, theta)
   return self:runPredict(newX, theta)
end
