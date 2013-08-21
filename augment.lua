-- augment.lua

-- insert a 1 into first position of vector
function augment(v)
   assert(type(v) == 'userdata' and
          v:dim() == 1,
          'v is not a 1D Tensor')
   local size = v:size(1)
   local result = torch.Tensor(size + 1)
   result[1] = 1
   for d = 1, size do
      result[d + 1] = v[d]
   end
   return result
end
