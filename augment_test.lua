-- augment_test.lua
-- unit test

require 'assertEq'
require 'augment'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local v = torch.Tensor{2,3,4}
local a = augment(v)
vp(1, 'a', a)

local expected = torch.Tensor{1,2,3,4}
vp(2, 'expected', expected)

assertEq(a, expected, 0)

print('ok augment')
