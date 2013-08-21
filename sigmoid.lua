-- sigmoid.lu

-- sigmoid of each element in a 2D Tensor
-- ARGS
-- z  : m x n Tensor or similar NamedMatrix
-- RETURNS
-- s  : m X n Tensor
function sigmoid(z)
   if torch.typename(z) == 'NamedMatrix' then
      return sigmoid(z.t)
   end

   assert(z:dim() == 2)
   local m = z:size(1)
   local n = z:size(2)

   local result = torch.cdiv(torch.ones(m, n),
                             torch.add(torch.ones(m,n),
                                       torch.exp(- z)))
   return result
end