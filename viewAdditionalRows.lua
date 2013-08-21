-- viewAdditionalRows.lua

-- return 2D view of storage used by 1D Tensor
-- ARGS:
-- tensor2D : 2D Tensor with 1 row
-- nRows    : integer > 0, number of rows in resulting view
--            number of columns in the view is the number of elements in 
--            tensor1D
-- RETURNS
-- view2D   : nRows x tensor1D:size(1) view of storage in tensor1D
--            changing view2D now changes tensor1D and vice versa
--            view2D[i][k] = tensor1D[k] for all i for all k
function viewAdditionalRows(tensor2D, nRows)
   assert(tensor2D:dim() == 2)
   assert(tensor2D:size(1) == 1)
   assert(nRows >= 1)
   return torch.Tensor(tensor2D:storage(),
                       1,                   -- offset into storage
                       nRows, 0,            -- size 1, stride 1
                       tensor2D:size(2), 1) -- size 2, stride 2
end

