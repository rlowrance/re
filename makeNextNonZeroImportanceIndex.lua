-- makeNextNonZeroImportanceIndex.lua

-- return function to randomly step through indices with non-zero weights
-- ARGS:
-- weights   : 2D Tensor size n X 1
-- RETURNS:
-- nextIndex : function() --> random selection from non-zero weight indices
function makeNextNonZeroImportanceIndex(weights)
   local vp = makeVp(0, 'makeNextNonZeroImportanceIndex')
   vp(1, 'weights', weights)

   -- validate args
   assert(weights:dim() == 2 and weights:size(2) == 1)
   local n = weights:size(1)

   -- build tensor containing randomized permutation of indices of weights that
   -- are not zero
   local nNonZero = torch.sum(torch.ne(weights, 0))
   local allPermutedIndices = torch.randperm(n)
   local nonZeroPermutedIndices = torch.Tensor(nNonZero)
   
   local nextNonZeroIndex = 0
   for i = 1, n do
      local index =  allPermutedIndices[i]
      if weights[index][1] ~= 0 then
         nextNonZeroIndex = nextNonZeroIndex + 1
            nonZeroPermutedIndices[nextNonZeroIndex] = index
      end
   end
   assert(nextNonZeroIndex == nNonZero)
   allPermutedIndices = nil
   
   local index = 0
   local function nextIndex()
      index = index + 1
      if index > nNonZero then
         index = 1
      end
      return nonZeroPermutedIndices[index]
   end
   
   return nextIndex
end
