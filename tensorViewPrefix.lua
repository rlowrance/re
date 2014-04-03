-- tensorViewPrefix.lua
-- view a prefix of a tensor
-- ARGS
-- t    : tensor of any underlying storage
-- len  : number of element in view, the view is t[1] t[2] ... t[len]
-- RETURNS
-- view : view of the first len elements of t
function tensorViewPrefix(t, len)
   local nDim = t:nDimension()
   assert(nDim == 1, 'not yet implemented for nDimension = ' .. tostring(nDim))
   local typename = torch.typename(t)
   if typename == 'torch.DoubleTensor' then
      return torch.DoubleTensor(t:storage(), 1, len, 1)
   elseif typename == 'torch.LongTensor' then
      return torch.LongTensor(t:storage(), 1, len, 1)
   else
      error('not yet implemented for typename(t) = ' .. typename)
   end
end
