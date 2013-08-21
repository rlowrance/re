-- checkGradient.lua

require 'makeVp'
require 'validateAttributes'

-- Determine if the derivative of a function is correctly computed
-- Ref: http://www.gatsby.ucl.ac.uk/~edward/code/minimize/example.html
--      which has a link to the matlab function checkgrad.m
-- This code replicates that function.

-- ARGS:
-- f        : function of one argument x, returning number f(x)
-- x        : 1D Tensor, point for evaluation of the derivative
-- epsilon  : number, circle size around x where derivative is checked
--            NOTE: if epsilon is very small, the division (y2 - y1)/(2*epsilon)
--            will be unstable and the results may falsely indicate that
--            the gradient is incorrect!
-- gradient : 1D Tensor, purported gradient at f(x) with respect to x
-- verbose  : boolean; if true, print element by element comparison of
--            supplied gradient and computed finite-difference gradient
-- RETURNS:
-- normDiff   : number, norm of difference between dh and gradient divided by 
--              norm of sum of dh and gradient
-- fdGradient : 1D Tensor, appoximated gradient at x
--              from perturbing each dimension by epsilon
function checkGradient(f, x, epsilon, gradient, verbose)
   local vp = makeVp(0, 'checkGradient')

   vp(1, 'f', f)
   vp(1, 'x', x)
   vp(1, 'epsilon', epsilon)
   vp(1, 'gradient', gradient)
   vp(1, 'verbose', verbose)

   -- validate args
   validateAttributes(f, 'function')
   validateAttributes(x, 'Tensor', '1D')
   validateAttributes(epsilon, 'number', '>', 0)
   validateAttributes(gradient, 'Tensor', '1D')
   validateAttributes(verbose, 'boolean')

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
      vp(3, string.format('y1=%15f y2=%15f fdGradient[%d]=%f', 
                          y1, y2, j, fdGradient[j]))
      vp(3, string.format(' num ' .. (y2 - y1) .. 
                          ' den ' .. (2 * epsilon)))
      if verbose then
         print(string.format('checkGradient: gradient[%d]=%15f fdGradient[%d]=%15f',
                             j, gradient[j], j, fdGradient[j]))
      end
   end

   vp(2, 'fdGradient', fdGradient)
   vp(2, 'dy', dy)


   local a = torch.norm(fdGradient - gradient)
   local b = torch.norm(fdGradient + gradient)
   local normDiff = a / b

   vp(1, 'normDiff', normDiff)
   vp(2, 'norm(fdGradient - gradient)', a)
   vp(2, 'norm(fdGradient + gradient)', b)
   vp(2, 'dy', dy)
   vp(1, 'fdGradient', fdGradient)
   
   return normDiff, fdGradient
end
