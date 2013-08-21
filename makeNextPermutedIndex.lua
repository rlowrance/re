-- makeNextPermutedIndex.lua

-- make function that returns elements from random permutation of {1, 2, ..., nIndices}
-- ARGS:
-- nIndex : number > 0, number of indices
-- RETURNS
-- nextIndex : function() --> an integer from {1, 2, ..., nIndices}
function makeNextPermutedIndex(nIndices)
   -- validate ARGS
   assert(type(nIndices) == 'number' and nIndices > 0)

   -- define state
   local permutedIndices = torch.randperm(nIndices)
   local index = 0

   local function nextIndex()
      index = index + 1
      if index > nIndices then
         index = 1
      end
      return permutedIndices[index]
   end

   return nextIndex
end

