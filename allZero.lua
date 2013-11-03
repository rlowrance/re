-- allZero.lua
-- return true iff tensor is zero is every position
-- ARGS;
-- t         : tensor of any size
-- RETURNS:
-- isAllZero : boolean, true iff every element is zero

require 'makeVp'
require 'validateAttributes'

function allZero(t)
   local vp = makeVp(2, 'allZero')
   validateAttributes(t, 'Tensor')

   return t:nElement() == torch.sum(torch.eq(t, 0))
end
