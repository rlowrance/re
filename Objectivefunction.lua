-- Objectivefunction.lua
-- abstract class for optimization function

if false then
   of = ObjectivefunctionSUBCLASS(subclass_parameters)

   -- implementation note: each method should do the minimum amount of work
   flatParameters = of:initialTheta()  -- return 1D Tensor
   number= of:loss(flatParameters)
   tensor1D = of:gradient(flatParameters)
   number, tensor1D = of:lossGradient(flatParameters)
   object = of:predictions(newX, theta)  -- type of object depends on subclass

   table = of:getNCalls()  -- table with number of calls to each of the methods
end

require 'printAllVariables'
require 'printTableVariable'
require 'torch'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local Objectivefunction = torch.class('Objectivefunction')

function Objectivefunction:__init()
   -- subclass will supply its own initialization
   self.nCalls = {}  -- number of times each function is called
   return
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return a tensor (flat parameters) with reasonable initial values
-- RETURN
-- flatParameters : Tensor 1D
function Objectivefunction:initialTheta()
   self.nCalls.initialTheta = (self.nCalls.initialTheta or 0) + 1
   if self.runInitialTheta then
      return self:runInitialTheta()
   end
end

-- return table of number of calls to each method
-- ARGS: NONE
-- RETURNS:
-- table          : key == method name, value == number times called
function Objectivefunction:getNCalls()
   self.nCalls.getNCalls = (self.nCalls.getNCalls or 0) + 1
   return self.nCalls
end

-- return gradient at the flat parameters
-- ARGS:
-- flatParameters : table returned by method loss()
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Objectivefunction:gradient(flatParameters)
   self.nCalls.gradient = (self.nCalls.gradient or 0) + 1
   if self.runGradient then
      return self:runGradient(flatParameters)
   end
end

-- return the loss at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Objectivefunction:loss(flatParameters)
   self.nCalls.loss = (self.nCalls.loss or 0) + 1
   if self.runLoss then
      return self:runLoss(flatParameters)
   end
end

-- return the loss and gradient at the flat parameters
-- ARGS:
-- flatParameters : Tensor 1D
-- RETURNS:
-- loss           : number
-- gradient       : Tensor 1D (includes gradient of regularizer)
function Objectivefunction:lossGradient(flatParameters)
   self.nCalls.lossGradient = (self.nCalls.lossGradient or 0) + 1
   if self.runLossGradient then
      return self:runLossGradient(flatParameters)
   end
end

-- return predictions at new features X using flat parameters
-- ARGS:
-- newX           : 2D Tensor, one row per observation
-- flatParameters : 1D Tensor
-- RETURNS
-- probabilies    : 2D Tensor, shape depends on subclass
function Objectivefunction:predictions(newX, flatParameters)
   self.nCalls.predictions = (self.nCalls.predictions or 0) + 1
   if self.runPredictions then
      return self:runPredictions(newX, flatParameters)
   end
end
