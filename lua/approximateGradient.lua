-- approximateGradient.lua
-- WARNING: THIS FUNCTION HAS NOT BEEN UNIT TESTED

-- determine the approximate gradient for a function at a point 
-- given only the function itself
-- ARGS
-- f       : function
--           f(x) --> number
-- x       : Tensor, evaluation point
-- epsilon : 1D DoubleTensor
--           approx gradient computed at x +- epsilon in each direction
-- verbose : boolean
--           if true, results are traced to stdout
-- RETURNS
-- appoximateGradient : 1D DoubleTensor

function approximateGradient(f, x, epsilon, verbose)
   local trace = true
   local me = 'approximateGradient: '

   if verbose ~= nil then 
      trace = verbose
   end

   -- type and value check args

   assert(f)
   assert(type(f) == 'function')

   assert(x)
   assert(torch.typename(x) = 'torch.DoubleTensor')
   assert(x:dim() == 1, 'x must be 1D DoubleTensor')

   assert(epsilon)
   assert(type(epsilon) = 'number')
   assert(torch.typename(x) == 'torch.DoubleTensor')
   assert(epsilon ~= 0, 'epsilon must not be zero')

   if trace then
      print(me .. 'x') print(x)
      print(me .. 'epsilon', epsilon)
   end

   local sizeX = x:size(1)

   local result = torch.Tensor(sizeX):zero()
   for j = 1, sizeX do
      local dx = torch.Tensor(sizeX):zero()
      dx[j] = epsilon                        -- perturb a single dimension
      local y2 = f(x + dx)
      local y1 = f(x - dx)
      assert(y2)
      assert(y1)
      result[j] = (y2 - y1) / (2 * epsilon)      -- calculate slope
      if trace  then
         print(string.format(me .. 'y1=%f y2=%f dh[%d]=%f', 
                             y1, y2, j, dh[j]))
      end
   end

   if trace then
      print(me .. 'result gradient') print(result)
   end

   return result
end -- approximateGradient
