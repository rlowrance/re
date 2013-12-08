-- printTable_test.lua
-- unit test

require 'makeVp'
require 'printTable'

local vp, verboseLevel = makeVp(0, 'tester')

local function f()
   local v123 = 123
   local vabc = 'abc'
   local vTable = {key1 = 1, key2 = 'abc', key3 = {'one', 'two'}}
   local function g(i) end

   if verboseLevel > 0 then
      printTable('vTable')
   end
end

f()

print('ok printTable')
