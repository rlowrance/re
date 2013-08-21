-- makeSampleIndexer.lua

-- return function than randomly indexes sample numbers
-- ARGS:
-- n : number > 0, number of samples
-- RETURNS one function
-- sampleIndex() return a random integer in [1, n]
function makeSampleIndexer(n)
   assert(type(n) == 'number' and
          n >= 1 and
          math.floor(n) == n,
          'n is not positive integer')
   
   local randomIndices = torch.randperm(n)
   local nextOffset = 0

   -- return randomly selected sample index
   local function sampleIndex()
      nextOffset = nextOffset + 1
      if nextOffset > n then
         nextOffset = 1
      end
      return randomIndices[nextOffset]
   end
   
   return sampleIndex
end