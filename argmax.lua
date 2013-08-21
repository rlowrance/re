-- argmax.lua


-- index of largest element
-- ARGS:
-- v : 1D torch.Tensor
-- RETURNS:
-- i : integer in [1, v:size(1)] such that v[i] >= v[k] for all k
function argmax1(v)
   assert(v:dim() == 1)

   local length = v:size(1)
   assert(length > 0)

   local maxValue = torch.max(v)
   
   -- should need to examine just 1/2 the entries on average
   for i = 1, length do
      if maxValue == v[i] then
         return i
      end
   end
   error('maxValue not in v')
end

function argmax2(v)
   assert(v:dim() == 1)

   local length = v:size(1)
   assert(length > 0)

   -- examine every entry
   local maxValue = -math.huge
   local maxIndex = nil
   for i = 1, length do
      local value = v[i]
      if value > maxValue then
         maxValue = value
         maxIndex = i
      end
   end
   return maxIndex
end

-- in timing tests, implementation 2 is often faster for all vector lengths
argmax = argmax2

