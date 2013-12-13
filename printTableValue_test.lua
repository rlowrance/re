-- printTableValue_test.lua
-- unit test

require 'makeVp'
require 'printTableValue'

local vp, verboseLevel = makeVp(0, 'tester')

local function f()
   local vTable = {key1 = 1, key2 = 'abc', key3 = {'one', 'two'}}
   
   if verboseLevel > 0 then
      printTableValue(vTable)
   end
end

f()

print('ok printTableValue')
