-- Accumulators_test.lua
-- unit test

require 'Accumulators'
require 'makeVp'
require 'printTableValue'

local vp = makeVp(2, 'tester')

local a = Accumulators()
local function value(name)
   if false then
      -- while debugging
      printTableValue('a.table', a:getTable())
   end
   return a:getTable()[name]
end
   
a:add1('x')
a:add1('x')
assert(value('x') == 2)

a:add('y', 10)
assert(value('y') == 10)

a:addAccumulators(a)
assert(value('x') == 4)
assert(value('y') == 20)

a:addTable({x = -2, z = 23})
assert(value('x') == 2)
assert(value('y') == 20)
assert(value('z') == 23)

local t = a:getTable()
local count = 0
for k, v in pairs(t) do
   count = count + 1
end
assert(count == 3)

print('ok Accumulators')
