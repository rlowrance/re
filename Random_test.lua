-- Random_test.lua
-- unit test

require 'makeVp'
require 'printTableValue'
require 'Random'
require 'round'

local vp, verboseLevel = makeVp(0, 'tester')

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

--local nSamples = 10
local r1 = Random():geometric(nSamples, lowest, highest)
vp(1, 'geometric r1', r1)
assert(r1:size(1) == nSamples)
local buckets = {}
for i = 1, nSamples do
   local value = r1[i]
   assert(lowest <= value, value)
   assert(value <= highest, value)
   local bucket = round(value, 0)
   vp(2, 'bucket', bucket)
   buckets[bucket] = (buckets[bucket] or 0) + 1
end
if verboseLevel > 0 then 
   printTableValue('buckets', buckets)
end


print('ok Random')
