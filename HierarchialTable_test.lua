-- HierarchialTable_test.lua
-- unit test

require 'HierarchialTable'
require 'makeVp'

local vp = makeVp(2, 'tester')

local ht = HierarchialTable(3)


ht:put(1, 2, 3, 'oneXXX')
assert(ht:get(1, 2, 3) == 'oneXXX')

ht:put(1, 2, 3, 'one')  -- replace first value
assert(ht:get(1, 2, 3) == 'one')

ht:put(1, 20, 30, 'two')
assert(ht:get(1, 2, 3) == 'one')
assert(ht:get(1, 20, 30) == 'two')

ht:put(1, 2, 40, 'three')

assert(ht:get(1, 2, 3) == 'one')
assert(ht:get(1, 20, 30) == 'two')
assert(ht:get(1, 2, 40) == 'three')
assert(ht:get(2, 3, 4) == nil)

local valuesFound = {}
local function walk(value)
   valuesFound[value] = true
end
ht:eachValue(walk)
assert(valuesFound['one'])
assert(valuesFound['two'])
assert(valuesFound['three'])

print('ok HierarchialTable')
