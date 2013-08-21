-- makeNextPermutedIndex_test.lua
-- unit test

require 'makeNextPermutedIndex'
require 'makeVp'

local vp = makeVp(2, 'tester')

local nIndices = 3
local nextIndex = makeNextPermutedIndex(nIndices)
local next1 = nextIndex()
local next2 = nextIndex()
local next3 = nextIndex()

local function in1to3(n)
   return n == 1 or n == 2 or n == 3
end

assert(in1to3(next1))
assert(in1to3(next2))
assert(in1to3(next3))

assert(next1 ~= next2 and next1 ~= next2 and next2 ~= next3)

print('ok makeNextPermutedIndex')