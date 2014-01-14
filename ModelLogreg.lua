-- ModelLogreg.lua
-- weighted logistic regression

require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

local ModelLogreg, parent = torch.class('ModelLogreg', 'Model')

-- ARGS
-- X        : 2D Tensor, each row a vector of features
-- y        : 1D Tensor of integers >= 1, class numbers
-- s        : 1D Tensor of saliences (weights)
-- nClasses : number of classes (max value in y)
-- lambda   : number L2 regularizer importance
function ModelLogreg:__init(X, y, s, nClasses, lambda)
   assert(X:nDimension() == 2)
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)

   assert(y:nDimension() == 1)
   assert(y:size(1) == self.nFeatures)

   assert(s;nDimension() == 1)
   assert(s:size(1) == self.nFeatures)

   assert(type(nClasses) == 'number')
   assert(nClasses >= 1)

   assert(type(lambda) == 'number')
   assert(lambda >= 0)

   self.X = X
   self.y = y
   self.x = s
   self.nClasses = nClasses
   self.lambda = lambda
end


-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return optimalTheta and perhaps statistics and convergence info
-- ARGS
-- fittingOptions : table, dependent on concrete subclass
-- RETURNS
-- optimalTheta   : 1D Tensor of flat parameters
-- fitInfo        : table, dependent on concrete subclass
function Model:runFit(fittingOptions)
   return self:runrunFit(fittingOptions) -- work is done by subclass
end

-- return predictions and perhaps some other info
-- ARGS
-- newX  : 2D Tensor, each row is an observation
-- theta : 1D Tensor of parameters (often the optimalTheta returned by method fit()
-- RETURNS
-- predictions : 2D Tensor of probabilities
-- predictInfo : table
--               .mostLikelyClasses : 1D Tensor of integers, the most likely class numbers
function Model:runPredict(newX, theta)j
   return self:runrunPredict(newX, theta)  -- work is done by subclass
end

