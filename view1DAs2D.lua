-- view1DAs2D.lua

-- return 2D view of storage used by 1D Tensor
-- ARGS:
-- tensor1D : 1D Tensor
-- nRows    : integer > 0, number of rows in resulting view
--            number of columns in the view is the number of elements in 
--            tensor1D
-- RETURNS
-- view2D   : nRows x tensor1D:size(1) view of storage in tensor1D
--            changing view2D now changes tensor1D and vice versa
--            view2D[i][k] = tensor1D[k] for all i for all k
function view1DAs2D(tensor1D, nRows)
   assert(tensor1D:dim() == 1, 'dim = ' .. tensor1D:dim())
   assert(nRows >= 1)
   return torch.Tensor(tensor1D:storage(),
                       1,                   -- offset
                       nRows, 0,            -- size 1, stride 1
                       tensor1D:size(1), 1) -- size 2, stride 2
end

