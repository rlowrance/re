-- distancesEuclidean.lua

require 'makeVp'

-- determine Euclidean distances to a query point
--
-- ARGS:
--
-- inputs: 2D tensor of size n x d
--
-- query: 1D Tensor of size d
--
-- RETURN 1D Tensor of size n
-- with Euclidean distance for query to each input row
function distancesEuclidean(inputs, query)
   assert(inputs:nDimension() == 2)
   local n = inputs:size(1)
   local d = inputs:size(2)
   assert(query:nDimension() == 1)
   assert(query:size(1) == d)

   verbose = 0
   local vp = makeVp(verbose)

   vp(1, 'inputs', inputs)
   vp(1, 'query', query)

   -- create synthetic query2D is size n x d
   local query2D = torch.Tensor(query:storage(),
                                1,  -- storageOffset
                                n, 0, -- sz1, st1
                                d, 1) -- sz2, st2
   -- test that we did this correctly
   vp(2, 'query2D', query2D)
   assert(query2D:nDimension() == 2)
   assert(query2D:size(1) == n)
   assert(query2D:size(2) == d)
   assert(query[1] == query2D[3][1])
   if d > 1 then
      assert(query[2] == query2D[1][2])
   end
   if d > 2 then
      assert(query[3] == query2D[2][3])
   end

   local diffs = inputs - query2D
   vp(2, 'diffs', diffs)
   local squares = torch.cmul(diffs, diffs)
  
   local sumSquares = torch.Tensor(n):zero()
   for i = 1, d do
      sumSquares = torch.add(sumSquares, squares:select(2, i))
   end

   local result = sumSquares:sqrt()
   vp(1, 'result', result)
   return result
end
