-- asFactor_test.lua
-- unit tests of asFactor

require 'asFactor'
require 'Dataframe'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local function assertEqSeq(s1, s2)
   local vp = makeVp(0, 'check assertEqSeq')
   vp(1, 's1', s1, 's2', s2)
   assert(#s1 == #s2)
   for i, s1Element in ipairs(s1) do
      assert(s1Element == s2[i])
   end
end

local function check(seq, expectedIndices, expectedLevels)
   local vp = makeVp(0, 'tester check')
   vp(1, 'seq', seq)
   
   local indices, levels = asFactor(seq, Dataframe.NA)
   vp(1, 'indices', indices)
   vp(1, 'levels', levels)
   
   assertEqSeq(indices, expectedIndices)
   assertEqSeq(levels, expectedLevels)
end

-- test with the most important NA value
local NA = Dataframe.NA 

local test1 = {'a', 'b', 'a', NA, 'c'}
check(test1, {1, 2, 1, NA, 3}, {'a', 'b', 'c'})

local test2 = {NA}
check(test2, {NA}, {})

print('ok asFactor')
