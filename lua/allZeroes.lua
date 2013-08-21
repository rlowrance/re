-- allZeroes.lua

require 'makeVerbose'
require 'verify'

function allZeroes(tensor)
   -- return true iff every element in the tensor is zero
   local v, isVerbose = makeVerbose(false, 'allZeroes')

   verify(v,
          isVerbose,
          {{tensor, 'tensor', 'isTensor'}})

   local nDim = tensor:nDimension()
   
   if nDim == 1 then
      for d = 1, tensor:size(1) do
         if tensor[d] ~= 0 then
            return false
         end
      end
      return true

   elseif nDim == 2 then
      for d1 = 1, tensor:size(1) do
         for d2 = 1, tensor:size(2) do
            if tensor[d1][d2] ~= 0 then
               return false
            end
         end
      end
      return true

   else
      error('this implementation handles only 1D and 2D tensors')
   end
end -- allZeroes