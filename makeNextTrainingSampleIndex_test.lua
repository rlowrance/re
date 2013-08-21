-- makeNextTrainingSampleIndex_test.lua
-- unit test

require 'makeNextTrainingSampleIndex'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose)

local isTraining = torch.Tensor({1, 0, 1, 0, 1}) -- [1,3,5]

local next = makeNextTrainingSampleIndex(isTraining)
local first = next()
local second = next()
local third = next()
vp(1, 'first', first)
vp(1, 'second', second)
vp(1, 'third', third)
assert(first ~= second)
assert(first ~= third)
assert(second ~= third)

local function isIn(value, seq)
   vp(1, 'value', value)
   vp(1, 'seq', seq)
   for _, element in ipairs(seq) do
      if element == value then
         return true
      end
   end
   return false
end

local expected = {1,3,5}
assert(isIn(first, expected))
assert(isIn(second, expected))
assert(isIn(third, expected))

-- should cycle
local fourth = next()
assert(first == fourth)
assert(second == next())
assert(third == next())

print('ok makeNextTrainingSampleIndex')