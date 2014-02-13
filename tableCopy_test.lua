-- tableCopy_test.lua
-- unit test

require 'equalObjectValues'
require 'makeVp'
require 'printTableValue'
require 'tableCopy'

local vp, verboseLevel = makeVp(2, 'tester')

local t = {
   x = 'one',
   b = 'two',
   c = {a = "a string", b = "b string"},
   d = false,
}

t[{1,2}] = 'seq 1 2'


local copy = tableCopy(t)
printTableValue('t', t)
printTableValue('copy', copy)

-- check except for table keys and values (which have been deep copied)
local function equalValue(a, b)
   for k, v in pairs(a) do
      if type(k) == 'table' then
         -- could search through all the keys in table b to find one that
         -- has equalObjectValue to k
         -- for now, skip this
      else
         if type(v) == 'table' then
            assert(equalObjectValues(v, b[k]))
         else
            assert(b[k] == v)
         end
      end
   end
end

equalValue(t, copy)

print('ok tableCopy')
