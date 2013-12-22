-- LogregOpfunc.lua
-- abstract class for opfunc for salience-weighted logistic regression

if false then
   -- API overview
   of = LogregOpfuncSUBCLASS(X, y, s, nClasses, lambda)

   flatParameters = of:initialTheta()
   num, lossInfo = of:loss(flatParameters)
   tensor = of:gradient(lossInfo)
end

require 'torch'

-- CONSTRUCTOR

local LogregOpfunc = torch.class('LogregOpfunc')

function LogregOpfunc:__init(X, y, s, nClasses, lambda)
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
   assert(lambda) -- make sure all parameters were supplied
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

