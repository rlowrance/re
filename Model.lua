-- Model.lua
-- Abstract class

if false then
   m = ModelCONCRETE_CLASS(X, y, otherParameters)
   optimalTheta, fitInfo = m:fit(fittingOptions)  -- fittingOptions depends on CONCRETE_CLASS
   predictions, predictionInfo = m:predict(newX, optimalTheta)
end

require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

local Model = torch.class('Model')

function Model:__init()
   -- subclass will supply its own initialization
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
function Model:fit(fittingOptions)
   return self:runFit(fittingOptions)
end

-- return predictions and perhaps some other info
-- ARGS
-- newX  : 2D Tensor, each row is an observation
-- theta : 1D Tensor of parameters (often the optimalTheta returned by method fit()
function Model:predict(newX, theta)
   return self:runPredict(newX, theta)
end

