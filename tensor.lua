-- tensor.lua
-- utilities for handling tensors

if false then
   t = tensor.concatenateHorizontally(t1, t2, t3)
   t = tensor.selected(tensor1D, tensorWithIndices)  -- return new tensor
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
-- t1       : 1D Tensor or 0D Tensor
-- ...      : additional 1D Tensors
-- RETURNS
-- tensor2D : 2D Tensor with each of t1, ... is column s
-- TODO: allow any type of tensor, this implementation works only DoubleTensors
function tensor.concatenateHorizontally(t1, ...)
   local vp = makeVp(0, 'tensor.concatenateHorizontally')
   vp(1, 't1', t1)

   local args = {...}
   vp(1, 'args', args)

   if #args == 0 then
      return t1:clone()
   else
      if t1:nDimension() == 0 then
         -- t1 is a dummy, like an empty 1D Tensor (a zero value)
         local t2 = args[1]
         local result = torch.Tensor(t2:size(1), #args)
         for i = 1, #args do
            copyToColumn(result, i, args[i])
         end
      else
         -- t1 is not a dummy
         local result = torch.Tensor(t1:size(1), 1 + #args)
         copyToColumn(result, 1, t1)
         for i = 1, #args do
            copyToColumn(result, 1 + i, args[i])
         end
         return result
      end
   end
end

-- return selected elements in tensor
-- ARGS
-- input    : tensor with one dimension
-- indices  : tensor with positive integers
-- RETURNS
-- result   : result[i] = tensor[indices[i]]
function tensor.selected(input, indices)
   assert(input:nDimension() == 1)
   local size = indices:nElement()
   local result = torch.Tensor(size):type(torch.typename(input))
   
   for i = 1, size do
      result[i] = input[indices[i]]
   end

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

