-- augment_test.lua
-- unit test

require 'assertEq'
require 'augment'
require 'makeVp'
require 'pp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local v = torch.Tensor{2,3,4}
local a = augment(v)
vp(1, 'a', a)

local expected = torch.Tensor{1,2,3,4}
vp(2, 'expected', expected)

assertEq(a, expected, 0)

local m = torch.rand(3, 10)
local mAugmented = augment(m)
--pp.tensor('m', m)
--pp.tensor('mAugmented', mAugmented)
assert(mAugmented:nDimension() == 2)
assert(mAugmented:size(1) == m:size(1))
assert(mAugmented:size(2) == m:size(2) + 1)
assert(mAugmented[1][1] == 1)
assert(mAugmented[1][2] == m[1][1])

print('ok augment')
