-- ObjectivefunctionLogreg.lua
-- abstract class for opfunc for salience-weighted logistic regression

if false then
   -- API overview (version 2 API)
   of = ObjectivefunctionLogregSUBCLASS(X, y, s, nClasses, L2)

   flatParameters = of:initialTheta()
   number= of:loss(flatParameters)
   tensor1D = of:gradient(flatParameters)
   loss, tensor1D = of:lossGradient(flatParameters)
   tensor2D = of:predictions(newX, theta)  -- newX is 2D Tensor
   
end

require 'Objectivefunction'
require 'printAllVariables'
require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local ObjectivefunctionLogreg, parent = torch.class('ObjectivefunctionLogreg', 'Objectivefunction')

function ObjectivefunctionLogreg:__init(X, y, s, nClasses, L2)
   parent.__init(self)
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

   L2 = L2 or 0  -- supply default
   assert(L2, 'L2 regularizer importance not supplied')
   assert(type(L2) == 'number', 'L2 is not a number')
   assert(L2 >= 0, 'L2 not non-negative')


   -- save args
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.L2 = L2
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return a tensor (flat parameters) with reasonable initial values
-- RETURN
-- flatParameters : Tensor 1D
function ObjectivefunctionLogreg:runInitialTheta()
   return self:runrunInitialTheta()
end

-- return gradient at the flat parameters
-- ARGS:
-- flatParameters : table returned by method loss()
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function ObjectivefunctionLogreg:runGradient(flatParameters)
   return self:runrunGradient(flatParameters)
end

-- return the loss at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function ObjectivefunctionLogreg:runLoss(flatParameters)
   return self:runrunLoss(flatParameters)
end

-- return the loss and gradient at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- loss           : number
-- gradient       : Tensor 1D (includes gradient of regularizer)
function ObjectivefunctionLogreg:runLossGradient(flatParameters)
   return self:runrunLossGradient(flatParameters)
end

-- return predictions at new features X using flat parameters
-- ARGS:
-- newX           : 2D Tensor, one row per observation
-- flatParameters : 1D Tensor
-- RETURNS
-- probabilies    : 2D Tensor, shape depends on subclass
function ObjectivefunctionLogreg:runPredictions(newX, flatParameters)
   return self:runrunPredictions(newX, flatParameters)
end
