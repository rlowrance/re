-- finiteDifferenceGradient.lua
-- determine gradient using finite differences
-- ARGS
-- f   : function of one 1D Tensor x, returning number f(x)
-- x   : 1D Tensor, point of evalution
-- epsislon : number, circle size around x for determining the gradient
-- RETURNS
-- fdGradient : 1D Tensor, gradient at x estimated through finite differences
function finiteDifferenceGradient(f, x, epsilon)
   local vp, verboseLevel = makeVp(0, 'finiteDifferenceGradient')
   local verbose = verboseLevel > 0

   vp(1, 'f', f, 'x', x, 'epsilon', epsilon)

   local sizeX = x:size(1)

   local fdGradient = torch.Tensor(sizeX)
   for j = 1, sizeX do
      local dx = torch.Tensor(sizeX):zero()
      dx[j] = epsilon                        -- perturb a single dimension
      local y2 = f(x + dx)
      local y1 = f(x - dx)
      assert(y2)
      assert(y1)
      fdGradient[j] = (y2 - y1) / (2 * epsilon)      -- calculate slope
      if verbose then
         vp(3, string.format('y1=%15f y2=%15f fdGradient[%d]=%f', 
                             y1, y2, j, fdGradient[j]))
         vp(3, string.format(' num ' .. (y2 - y1) .. 
                             ' den ' .. (2 * epsilon)))
      end
   end

   vp(1, 'fdGradient', fdGradient)
   return fdGradient
end
