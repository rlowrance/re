-- Kernel.lua
-- define various kernels

local Kernel = torch.class('Kernel')

function Kernel.__init()
end

-- see Hastie-01 p. 166-167
-- static method
function Kernel.epanechnikov(query, x, lambda, distance)
   function d(dist, lambda)
      local t = dist / lambda
      if math.abs(t) <= 1 then
         return 0.75 * (1 - t * t)
      else
         return 0
      end
   end

   if false then
      print('Kernel params', query, x, lambda, distance)
      print('Kernel distance(query,x)', distance(query,x))
      print('Kernel d(...)', d(distance(query,x), lambda))
   end
   return d(distance(query, x), lambda)
end

   