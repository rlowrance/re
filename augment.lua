-- augment.lua

-- insert a 1 into first position of vector or matrix
function augment(t)
   local nDimension = t:nDimension()
   if nDimension == 1 then
      local size = t:size(1)
      local result = torch.Tensor(size + 1)
      result[1] = 1
      for d = 1, size do
         result[d + 1] = t[d]
      end
      return result
   elseif nDimension == 2 then
      -- reduce to vector case
      local size1 = t:size(1)
      local size2 = t:size(2)
      local result = torch.Tensor(size1, size2 + 1)
      for i = 1, size1 do
         result[i] = augment(t[i])
      end
      return result
   else
      error('t not 1D nor 2D')
   end
end
