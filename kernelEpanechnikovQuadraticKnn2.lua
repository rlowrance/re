-- kernelEpanechnikovQuadraticKnn2.lua

require 'allZero'
require 'head'
require 'makeVp'

-- determine weights for k-nearest neighbors using Epanechnikov quadratic kernel
-- ref: Hastie-01 p 167
-- ARGS
-- distances : 1D Tensor of size n of distances from query (x_0 in text)
-- k         : number of neighbors to consider
--
-- RETURNS
-- weights   : 1D Tensor of size n, at most k values are non-zero
-- errorMsg  : optional string, if not nil, an exception occured
--
-- Notes:
-- K_k(q, x) = D(|x - q| / h_k(q)) 
-- D(t) = if |t| <= 1 then .75(1 - t^2) else 0
-- h_k(q) = |q - x_[k] | = lambda
-- x_[k] = kth closest x_i to q
function kernelEpanechnikovQuadraticKnn2(distances, k)
   local vp, verboseLevel = makeVp(0, 'kernelEpanechnikovQuadraticKnn2')
   local v = verboseLevel > 0
   if v then vp(1, 'distances', distances, 'k', k) end

   -- validate args
   assert(distances:dim() == 1)
   assert(type(k) == 'number' and k > 0)

   
   local n = distances:size(1)
   local _, sortedIndices = torch.sort(distances)

   -- if the distance to the kth closest x_i to q is zero, then 
   --   the first k distances are all zero
   --   hence all the t values in D(t) are greater than 1
   --   hence all the D() are 0
   local lambda = distances[sortedIndices[k]]
   if lambda == 0 then
      return torch.Tensor(n):zero(), 'kth closest has zero distance'
   end


   local t = distances / lambda

   -- Epanenchnikov Quadratic Kernel is
   -- K(q, x) = D(distance(q,x) / lambda) where
   -- D(t) = ifelse(abs(t) <= 1, 3/4 * (1 - t^2), 0)
   local ones = t:clone():fill(1)
   local lessThanOne = torch.le(t:abs(), 1):type('torch.DoubleTensor')
   local weights = torch.cmul(lessThanOne,
                              (ones - torch.cmul(t, t)) * 0.75)

   if allZero(weights) then
      return weights, 'all zero'
   else
      return weights, nil
   end
end


   
