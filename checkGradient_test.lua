-- checkGradient-test.lua
-- unit test of checkGradient function

require 'checkGradient'
require 'Tester'

tests = {}
tester = Tester()




function tests.d1()
   local trace = false
   local me = 'tests.d1: '

   local function f(x)
      -- RETURN
      -- f(x) = x^2
      -- gradient(x) = [2x]
      local trace = false
      local me = me .. 'f: '
      local x1 = x[1]
      local f = x1 * x1
      local gradient = torch.Tensor(1)
      gradient[1] = 2 * x1
      if trace then
         print(string.format(me .. 'x [%.15f]', x1))
         print(string.format(me .. 'gradient f %.15f', f))
         print(me .. 'gradient', gradient)
      end
      return x1 * x1, gradient
   end

   local epsilon = 1

   local a = torch.Tensor(1):fill(3)
   local _, gradient = f(a)
   local verbose = false
   local d, dy, dh = checkGradient(f, a, epsilon, gradient, verbose)
   if trace then
      print('a', a)
      print('d', d)
      print('dy', dy)
      print('dh', dh)
   end
   tester:assertle(d, 1e-10, 'd is small')

   local b = torch.Tensor(1):fill(3)
   epsilon = 1e-1
   local _, gradient = f(b)
   local verbose = false
   local d, dy = checkGradient(f, b, epsilon, gradient, verbose)
   if trace then
      print('b', b)
      print('d', d)
      print('dy', dy)
      print('gradient', gradient)
   end
   tester:assertle(d, 1e-10, 'd is small')
end

function tests.d2()
   local trace = false

   function f(x)
      -- RETURN
      -- f(x) = 0.5 * x1^2 + 5 * x2^2
      -- gradient(x) = [x1, 10 x2]
      local trace = false
      local x1 = x[1]
      local x2 = x[2]
      local f = 0.5 * x1 * x1 + 5 * x2 * x2
      local gradient = torch.Tensor(2)
      gradient[1] = x1
      gradient[2] = 10 * x2
      if trace then
         print('\n')
         print('gradient x', x)
         print('gradient f', f)
         print('gradient gradient', gradient)
      end
      return 0.5 * x1 * x1 + 5 * x2 * x2, gradient
   end

   local x = torch.Tensor(2):fill(1)
   local epsilon = 1e-5
   local _, gradient = f(x)
   local verbose = false
   local d, dy = checkGradient(f, x, epsilon, gradient, verbose)
   if trace then
      print('\n')
      print('x', x)
      print('d', d)
      print('dy', dy)
      print('gradient', gradient)
   end
   tester:assertle(d, 1e-10, 'd is small')
end

--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

--tester:add({tests.three})
tester:add(tests)
local verbose = false
tester:run(verbose, 'checkGradient')


