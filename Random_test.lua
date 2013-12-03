-- Random_test.lua
-- unit test

require 'makeVp'
require 'Random'

local nSamples = 100
local lowest = 1
local highest = 10

local function within(x)
   assert(lowest <= x)
   assert(x <= highest)
end

local r1 = Random():uniform(nSamples, lowest, highest)
assert(r1:size(1) == nSamples)
r1:apply(within)

local function isInteger(x)
   assert(math.floor(x) == math.ceil(x))
end

local r1 = Random():integer(nSamples, lowest, highest)
assert(r1:size(1) == nSamples)
r1:apply(within)
r1:apply(isInteger)

print('ok Random')
