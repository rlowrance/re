-- modelX.lua
-- sample model with supposed best practices

-- principles (reasons):
-- all matrix and results are 2D Tensors
--   mimic Matlab code
--   avoid having to test for 1D vs. 2D
-- accept a NamedTensor whenever a Tensor is taken
-- provide extra args in name-value pairs
--   mimic common Matlab practice
--   avoid need to classes, thus making porting to Octave easier

-- name-value pairs supported (where applicable to function)
-- 'regularizer', {'L2', 'L1'}                : kind of regularizer if any
-- 'lambda', number                           : importance of regularizer
-- 'weights', 2D Tensor of size m x 1         : weights for observations
-- 'fitMethod', {'optim.lbfgs', 'optim.sgd'}  : how to fit parameters
-- 'fitParameters', obj                       : used in fitting

-- return a Theta value that is all zeros
-- ARGS
-- X : 2D Tensor of size m X n (or NamedTensor)
-- y : 2D Tensor, most likely m X 1
-- RETURNS 1 obj
-- Theta: obj of some type, perhaps a 2D Tensor
function modelXZeroTheta(X, y, ...)
   return nil
end


-- make a prediction
-- ARGS
-- Theta : 2D Tensor of size r x s (or NamedTensor)
-- X     : 2D Tensor of size m x n (or NamedTensor)
-- RETURNS at least 1 result
-- yHat : 2D Tensor
-- probs : 2D Tensor (or other, depending on model)
function modelXPredict(Theta, X, ...)
   -- pull Tensor out of any NamedTensor
   if torch.typename(Theta) == 'NamedTensor' then
      return modelXPredict(Theta.t, X, ...)
   end
   if torch.typename(X) == 'NamedTensor' then
      return modelXPredict(Theta, X, ...)
   end
   -- normal processing

   return nil
end

-- detemine cost and gradient at given Theta and samples
-- ARGS
-- Theta : 2D Tensor of size r x s (or NamedTensor)
-- X     : 2D Tensor of size m x n (or NamedTensor)
-- y     : 2D Tensor of size m x 1 (or NamedTensor)
-- RETURNS 2 results
-- cost     : number, the cost 
-- gradient : 2D Tensor of size r x s
function modelXCostGradient(Theta, X, y, ...)
   return nil
end

-- find optimal theta 
-- ARGS
-- X     : 2D Tensor of size m x n (or NamedTensor)
-- y     : 2D Tensor of size m x 1 (or NamedTensor)
-- RETURNS 2 results
-- Theta    : 2D Tensor, the optimal parameters
-- info     : obj, as specified by modelX
function modelXFit(X, y, ...)
   return nil, nil
end


