-- isTensor.lua
-- is a value some kind of torch.Tensor
function isTensor(value)
   local typename = torch.typename(value)
   return typename == 'torch.DoubleTensor' or
          typename == 'torch.FloatTensor' or
          typename == 'torch.LongTensor' or
          typename == 'torch.ByteTensor' or
          typename == 'torch.CharTensor' or
          typename == 'torch.IntTensor'
end

