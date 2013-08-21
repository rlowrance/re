-- view 1D Tensor as n x 1 column vector (2D Tensor)
-- ARGS:
-- tensor1D : 1D Tensor
-- RETURNS
-- view2D   : nRows x tensor1D:size(1) view of storage in tensor1D
--            changing view2D now changes tensor1D and vice versa
--            view2D[i][k] = tensor1D[k] for all i for all k
function viewAsColumnVector(tensor1D)
   assert(tensor1D:dim() == 1, 'dim = ' .. tensor1D:dim())
   local nRows = tensor1D:size(1)
   return torch.Tensor(tensor1D:storage(),
                       1,                   -- offset
                       nRows, 1,            -- size 1, stride 1
                       1, 0)                -- size 2, stride 2
end

