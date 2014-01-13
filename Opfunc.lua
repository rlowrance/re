-- Opfunc.lua
-- abstract class for optimization function

if false then
   of = OpfuncSUBCLASS(ubclass_parameters)

   -- implementation note: each method should do the minimum amount of work
   flatParameters = of:initialTheta()  -- return 1D Tensor
   number= of:loss(flatParameters)
   tensor1D = of:gradient(flatParameters)
   number, tensor1D = of:lossGradient(flatParameters)
   object = of:predictions(newX, theta)  -- type of object depends on subclass
end

require 'printAllVariables'
require 'printTableVariable'
require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local Opfunc = torch.class('Opfunc')

function Opfunc:__init()
   -- subclass will supply its own initialization
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return a tensor (flat parameters) with reasonable initial values
-- RETURN
-- flatParameters : Tensor 1D
function Opfunc:initialTheta()
   return self:runInitialTheta()
end

-- return gradient at the flat parameters
-- ARGS:
-- flatParameters : table returned by method loss()
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Opfunc:gradient(flatParameters)
   return self:runGradient(flatParameters)
end

-- return the loss at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Opfunc:loss(flatParameters)
   return self:runLoss(flatParameters)
end

-- return the loss and gradient at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- loss           : number
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Opfunc:lossGradient(flatParameters)
   return self:runLossGradient(flatParameters)
end

-- return predictions at new features X using flat parameters
-- ARGS:
-- newX           : 2D Tensor, one row per observation
-- flatParameters : 1D Tensor
-- RETURNS
-- probabilies    : 2D Tensor, shape depends on subclass
function Opfunc:predictions(newX, flatParameters)
   return self:runPredictions(newX, flatParameters)
end
