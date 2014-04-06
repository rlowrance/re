-- tensor.lua
-- utilities for handling tensors

if false then
   t = tensor.concatenateHorizontally(t1, t2, t3)
   t = tensor.viewColumn(tensor2D, columnIndex) -- return view of 1D Tensor
   t = tensor.viewPrefix(tensor1D, k)           -- return view of first k elements
end

tensor = {}

local function copyToColumn(tensor2D, columnIndex, tensor1D)
   for i = 1, tensor1D:size(1) do
      tensor2D[i][columnIndex] = tensor1D[i]
   end
end

-- tensor.concatenateHorizontally
-- ARGS
-- t1       : 1D Tensor
-- ...      : additional 1D Tensors
-- RETURNS
-- tensor2D : 2D Tensor with each of t1, ... is column s
function tensor.concatenateHorizontally(t1, t2, t3, t4)
   -- TODO: allow variable number of arguments
   -- TODO: allow any type of tensor
   local nRows = t1:size(1)
   assert(t2:size(1) == nRows)
   assert(t3:size(1) == nRows)
   assert(t4:size(1) == nRows)
   assert(torch.typename(t1) == 'torch.DoubleTensor')
   assert(torch.typename(t2) == 'torch.DoubleTensor')
   assert(torch.typename(t3) == 'torch.DoubleTensor')
   assert(torch.typename(t4) == 'torch.DoubleTensor')

   local result = torch.DoubleTensor(nRows, 4)
   copyToColumn(result, 1, t1)
   copyToColumn(result, 2, t2)
   copyToColumn(result, 3, t3)
   copyToColumn(result, 4, t4)

   return result
end

-- tensor.viewColumn
-- view the underlying storage of a column in a 2D Tensor
-- ARGS
-- tensor : 2D Tensor
-- columnIndex : number > 0, column to view
-- RETURNS
-- view        : tensor viewing the appropriate column
--               CHANGING THE VIEW ALSO CHANGES tensor
function tensor.viewColumn(tensor, columnIndex)
   assert(columnIndex > 0)
   assert(columnIndex <= tensor:size(2))
   return tensor:select(2, columnIndex)
end

-- tensor.viewPrefix.lua
-- view a prefix of a tensor
-- ARGS
-- t    : tensor of any underlying storage
-- len  : number of element in view, the view is t[1] t[2] ... t[len]
-- RETURNS
-- view : view of the first len elements of t
function tensor.viewPrefix(t, len)
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

