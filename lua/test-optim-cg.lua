-- test-optim-cg.lua
-- regression test of Koray's optim.cg function
-- uses example from Heath, p. 284

require 'optim'

--------------------------------------------------------------------------------
-- opfunc
--------------------------------------------------------------------------------

-- f(x) = 0.5 x_1^2 + 2.5 x_2^2
-- gradient(x) = [x_1, 5 * x_2]
-- NOTE: f ix minimized at [0,0]
-- ARGS:
-- x : 1D tensor of size 2
-- RETURNS:
-- f(x) : value at x
-- gradient(x): gradient at x
function opfunc(x)
   local x1 = x[1]
   local x2 = x[2]
   local f = 0.5 * x1 * x1 + 2.5 * x2 * x2
   local gradient = torch.Tensor(2)
   gradient[1] = x1
   gradient[2] = 5 * x2
   return f, gradient
end

   

--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

local xInitial = torch.Tensor(2)
xInitial[1] = 5
xInitial[2] = 1

print('opfunc(xInitial)', opfunc(xInitial))

local params = {} -- use defaults

xStar, fx = optim.cg(opfunc, xInitial, params)

print('xStar', xStar)
print('fx', fx)
