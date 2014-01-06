-- LogregOpfunc.lua
-- abstract class for opfunc for salience-weighted logistic regression

if false then
   -- API overview
   of = LogregOpfuncSUBCLASS(X, y, s, nClasses, lambda)

   flatParameters = of:initialTheta()
   num, lossInfo = of:loss(flatParameters)
   tensor = of:gradient(lossInfo)
end

require 'printAllVariables'
require 'torch'

-- CONSTRUCTOR

local LogregOpfunc = torch.class('LogregOpfunc')

function LogregOpfunc:__init(X, y, s, nClasses, lambda)
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

   assert(lambda, 'lmabda not supplied')
   assert(type(lambda) == 'number', 'lambda is not a number')
   assert(lambda >= 0, 'lambda not non-negative')


   -- save args
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
end

-- PUBLIC METHODS

-- RETURN
-- flatParameters : Tensor 1D
function LogregOpfunc:initialTheta()
   return self:runInitialTheta()
end

-- ARGS:
-- lossInfo : table returned by method loss()
-- RETURNS:
-- gradient : Tensor 1D (includes gradient of regularizer)
function LogregOpfunc:gradient(lossInfo)
   return self:runGradient(lossInfo)
end

-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS
-- loss     : number, regularized loss
-- lossInfo : table, argument for method gradient()
function LogregOpfunc:loss(flatParameters)
   return self:runLoss(flatParameters)
end

