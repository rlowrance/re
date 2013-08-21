-- optim_gd.lua

require 'makeVp'
require 'optim'

-- gradient descent with optional annealing of the learning rate alpha
-- ARGS:
-- alpha      : positive number
-- theta      : 1D Tensor, initial theta
-- converged  : function(newLoss, newTheta, newGradient)
--              returns true iff the iterations should stop
-- gradient   : function(theta)
-- loss       : function(theta)
-- onIncrease : optional string, default 'error'
--              what to do if the loss increases; choices are
--                'error'    : raise error('loss increased')
--                'decrease' : attempt to decrease alpha
--                             if not successful, then
--                                raise error('unsuccesful decrease')
-- RETURNS normally 3 the two values passed to converged()
-- finalLoss  : number
-- finalTheta : 1D Tensor, value of paramater at converge
-- finalAlpha : number
function optim.gd(alpha, theta, converged, gradient, loss, onIncrease)
   local vp = makeVp(0, 'optim.gd')
   -- validate args
   assert(type(alpha) == 'number' and
          alpha > 0,
          'alpha not positive number')
   assert(type(theta) == 'userdata' and
          theta:dim() == 1,
          'theta not 1D Tensor')
   assert(type(converged) == 'function',
          'converged not a function')
   assert(type(gradient) == 'function',
          'gradient not a function')
   assert(type(loss) == 'function',
          'loss not a function')

   -- provide default value
   if onIncrease == nil then
      onIncrease = 'error'
   end

   assert(onIncrease == 'error' or 
          onIncrease == 'decrease',
          'onIncrease not "error" nor "decrease"; is ' .. onIncrease)
   assert(onIncrease == 'error')

   local lastLoss = nil
   local lastTheta = theta:clone()
   repeat
      local g = gradient(lastTheta)
      local newTheta = lastTheta - g * alpha
      local newLoss = loss(newTheta)
      vp(3, ' ')
      vp(3, 'g', g)
      vp(3, 'alpha', alpha)
      vp(3, 'lastTheta', lastTheta)
      vp(3, 'newTheta', newTheta)
      vp(3, 'lastLoss', lastLoss)
      vp(3, 'newLoss', newLoss)
      if lastLoss ~= nil and newLoss > lastLoss then
         -- the loss increased; probably alpha is too large
         if onIncrease == 'error' then
            error('loss increased')
         else
            -- attempt to reduce alpha
            stop()
            repeat 
               alpha = .9 * alpha
               vp(2, 'alpha decreased to', alpha)
               newTheta = lastTheta - g * alpha
               newLoss = loss(newTheta)
            until newLoss <= lastLoss or alpha < 1e-16
            if alpha < 1e-16 then
               error('unsuccesful decrease')
            end
         end
      end
      lastLoss = newLoss
      lastTheta = newTheta
   until converged(newLoss, newTheta, g)
   return lastLoss, lastTheta, alpha
end

