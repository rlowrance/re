-- equalTensors.lua

require 'makeVp'

-- return true iff two tensors have the same sizes and same element values
-- ARGS
-- a : Tensor
-- b : Tensor
-- RETURNS
-- isEqual : true or false
function equalTensors(a, b)
   local vp, verboseLevel = makeVp(0, 'equalTensors')
   vp(1, 'a', a, 'b', b)
   
   assert(torch.typename(a) == 'torch.DoubleTensor', type(a))  -- TODO: allow other kinds
   assert(torch.typename(b) == 'torch.DoubleTensor', type(b))

   vp(2, 'a:dim()', a:dim(), 'b:dim()', b:dim())
   if a:dim() ~= b:dim() then
      return false
   end

   vp(2, 'a:size()', a:size(), 'b:size()', b:size())
   if a:dim() >= 1 then
      if a:size(1) ~= b:size(1) then
         return false
      end
   end

   if a:dim() >= 2 then
      if a:size(2) ~= b:size(2) then
         return false
      end
   end

   assert(a:dim() <= 2, 'not implemented for more than 2 dimensions')

   if verboseLevel >= 2 then
      vp(2, 'torch.ne(a,b)', torch.ne(a,b), 'nDifferences', torch.sum(torch.ne(a,b)))
   end

   local nDifferences = torch.sum(torch.ne(a, b))
   return nDifferences == 0
end
