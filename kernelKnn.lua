-- kernelKnn.lua

require 'allZero'
require 'head'
require 'makeVp'

-- determine weights in {0, 1} for k-nearest neighbors
-- ref: Hastie-01 p 167
-- ARGS
-- distances : 1D Tensor of size n of distances from query (x_0 in text)
-- k         : number of neighbors to consider
--
-- RETURNS
-- weights   : 1D Tensor of size n with values in {0, 1}, at most k values are non-zero
-- errorMsg  : optional string, if not nil, an exception occured
function kernelKnn(distances, k)
   -- validate args
   assert(distances:dim() == 1)
   assert(type(k) == 'number' and k > 0)
   
   local _, sortedIndices = torch.sort(distances)
   
   local weights = torch.Tensor(distances:size(1)):zero()

   for i = 1, k do
      weights[sortedIndices[i]] = 1
   end

   return weights, nil
end
