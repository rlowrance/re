-- setUnion_test.lua
-- unit test

require 'makeVp'
require 'setUnion'

local function makeSet(seq)
   local result = {}
   for _, element in ipairs(seq) do
      result[element] = true
   end
   return result
end

local set1 = makeSet({1,2,3})
local set2 = makeSet({3,4,5})

local union = setUnion(set1, set2)

assert(union[1] == true)
assert(union[2] == true)
assert(union[3] == true)
assert(union[4] == true)
assert(union[5] == true)

assert(union[6] ~= true)
print('ok setUnion')
