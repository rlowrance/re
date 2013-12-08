-- variableValue_test.lua
-- unit test

require 'makeVp'
require 'variableValue'

local vp = makeVp(0, 'tester')

function f()
   local v123 = 123
   local value = variableValue('v123')
   vp(2, 'value', value)
   assert(value == 123)
end

f()

print('ok variableValue')
