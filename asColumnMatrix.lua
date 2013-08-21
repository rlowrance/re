-- asColumnMatrix.lua

-- view 1D Tensor of size n as 2D Tensor of size n x 1
-- ARG
-- t : 1D Tensor
-- RETURNS
-- view : 2D Tensor using same storage as t
function asColumnMatrix(t)
   assert(t:dim() == 1)
   local n = t:size(1)
   return torch.Tensor(t:storage(),
                       1,             -- offset
                       n, 1,          -- size 1, stride 1
                       1, 0)          -- size 2, stride 2
end