-- concatHorizontal.lua

-- concatenate two 2D Tensor horizontally
-- ARGS
-- a : 2D Tensor of size m x n
-- b : 2D Tensor of size m x k
-- RETURN
-- result : 2D Tensor of size m x (n + k)
function concatHorizontal(a, b)
   local vp, verbose = makeVp(0, 'concatHorizontal')
   local d = verbose > 0
   if d then vp(1, 'a', a, 'b', b) end
   assert(a:dim() == 2)
   assert(b:dim() == 2)

   local m = a:size(1)
   local n = a:size(2)
   local k = b:size(2)
   if d then vp(2, 'm', m, 'n', n, 'k', k) end

   assert(b:size(1) == m)

   local result = torch.Tensor(m, n + k)

   for r = 1, m do
      for c = 1, n do
         result[r][c] = a[r][c]
      end
      for c = 1, k do
         result[r][n + c] = b[r][c]
      end
   end

   return result
end
      