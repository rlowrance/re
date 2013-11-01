-- kernelEpanechnikovQuadraticKnn.lua

require 'head'
require 'makeVp'

-- determine weights for k-nearest neighbors using Epanechnikov quadratic kernel
-- ref: Hastie-01 p 167
-- ARGS
-- distances : 1D Tensor of size n of distances from query (x_0 in text)
-- k         : number of neighbors to consider
-- sortedIndices : optional 1D Tensor of low-to-high sorted indices for the distances
--                 distances[sortedIndices[k]] is the distance from the query to the
--                 k-th observation closest to the query point
-- RETURNS
-- weights   : 1D Tensor of size n, only k values are non-zero
function kernelEpanechnikovQuadraticKnn(distances, k, sortedIndices)
   local vp, verboseLevel = makeVp(0, 'kernelEpanechnikovQuadraticKnn')
   local v = verboseLevel > 0
   if v then
      vp(1,
         'distances size', distances:size(),
         'distances head', head(distances),
         'k', k)
   end

   -- validate args
   assert(distances:dim() == 1)
   assert(type(k) == 'number' and k > 0)
   assert(sortedIndices == nil or sortedIndices:dim() == 1)

   -- provide default value for sortedIndices
   if sortedIndices == nil then
      _, sortedIndices = torch.sort(distances)
      if v then vp(1, 'sortedIndices head', head(sortedIndices)) end
   end

   -- avoid division by zero by keeping lambda away from zero
   -- lambda is the kernel width (using the notation in the text)
   local epsilon = 1e-10
   local lambda = distances[sortedIndices[k]]
   vp(2, 'lambda', lambda)
   if lambda == 0 then
      lambda = epsilon
   end
   assert(lambda > 0, 'bad lambda = ' .. tostring(lambda))

   local t = distances / lambda

   -- Epanenchnikov Quadratic Kernel is
   -- K(q, x) = D(distance(q,x) / lambda) where
   -- D(t) = ifelse(abs(t) <= 1, 3/4 * (1 - t^2), 0)
   local ones = t:clone():fill(1)
   local lessThanOne = torch.le(t:abs(), 1):type('torch.DoubleTensor')
   local weights = torch.cmul(lessThanOne,
                              (ones - torch.cmul(t, t)) * 0.75)

   assert(torch.sum(torch.lt(weights, 0)) == 0,
          'at least one negative weight')

   assert(torch.sum(torch.eq(weights, 0)) < weights:size(1),
          'all weights are zero')

   if verboseLevel == 3 then
      -- print non-zero weights
      vp(3, string.format('%d non-zero weights', k - 1))
      for i = 1, weights:size(1) do
         if weights[i] ~= 0 then
            vp(3, string.format(' weights[%d] = %f', i, weights[i]))
         end
      end
   end
      
   if v then
      --vp(2, 'weights', weights)
      vp(1, 'weights head', head(weights))
   end

   return weights
end


   
