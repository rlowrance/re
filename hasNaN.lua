-- hasNaN.lua

require 'ifelse'
require 'isnan'

-- return true iff there is at least one NA in a Tensor
-- ARGS
-- tensor  : 1D or 2D Tensor
-- verbose : optional integer >= 0, default 0
-- RETURNS true iff there is at least one NaN somewhere in the tensor
function hasNaN(tensor, verbose)
   local verboseValue = ifelse(verbose == true, 
                               1, 
                               ifelse(type(verbose) == 'number',
                                      verbose,
                                      0))
   local vp = makeVp(verboseValue, 'hasNaN')

   if tensor:dim() == 1 then
      for i = 1, tensor:size(1) do
         if isnan(tensor[i]) then
            return true
         end
      end
      return false
   elseif tensor:dim() == 2 then
      for i = 1, tensor:size(1) do
         for j = 1, tensor:size(2) do
            if isnan(tensor[i][j]) then
               return true
            end
         end
      end
      return false
   else
      error(string.format('not implemented for %d dimensions',
                          tensor:dim()))
   end
end