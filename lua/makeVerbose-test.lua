-- makeVerbose-test.lua
-- unit test of makeVerbose

require 'makeVerbose'

function test(tracing)
   local verbose, trace = makeVerbose(tracing, 'test')
   assert(trace == tracing)
   verbose('message')
   local a = 10
   local b = 20
   verbose('a,b', a, b)
   local t = {1,2,3}
   verbose('table', t)
   verbose('table,a', t, a)
   local tensor = torch.rand(2,3)
   verbose('tensor', tensor)
   local largeTensor1D = torch.rand(50)
   verbose('largeTensor1D', largeTensor1D)
   local largeTensor2D = torch.rand(100,6)
   verbose('largeTensor2D', largeTensor2D)
   
end

--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------

print('should print verbose material')
test(true)
print('should not print starting here')
test(false)
