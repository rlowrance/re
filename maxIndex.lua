-- maxIndex.lua

-- return index of largest value in vector
-- ARGS
-- v : n x 1 Tensor or 1D Tensor
-- RETURNS
-- index : number, index of the largest element
function maxIndex(v)

   -- detect and handle n x 1 Tensor
   if v:dim() == 2 then
      assert(v:size(2) == 1)
      local view = torch.Tensor(v:storage(),   -- view as 1D
                                1,
                                v:size(1), 1)
      return maxIndex(view)   -- 1D result returned
   end

   assert(type(v) == 'userdata' and
          v:dim() == 1)
   local largestValue = - math.huge
   local largestIndex = nil
   for i = 1, v:size(1) do
      local value = v[i]
      if value > largestValue then
         largestValue = value
         largestIndex = i
      end
   end
   return largestIndex
end
