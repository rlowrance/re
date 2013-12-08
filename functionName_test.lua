-- functionName_test.lua
-- unit test

require 'functionName'
require 'makeVp'

local vp = makeVp(0, 'tester')

function f()
   local fn = functionName()
   vp(2, 'fn', fn)
   assert(fn == 'f')
end

f()

print('ok functionName')
