-- StackFrame_test.lua
-- unit test

require 'makeVp'
require 'StackFrame'

local vp = makeVp(2, 'tester')

local function checkStackFrame()
   local sf = StackFrame('caller')
   assert(sf:functionName() == 'f')
   assert(sf:variableValue('v123'), 123)
end

local function f()
   local v123 = 123
   checkStackFrame()
end

f()

print('ok StackFrame')
