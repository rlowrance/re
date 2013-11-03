-- allZero_test.lua
-- unit test

require 'allZero'
require 'makeVp'

local vp = makeVp(2, 'tester')

local tZero1 = torch.zeros(10)
local tZero2 = torch.zeros(10, 10)
local tZero3 = torch.zeros(10, 10, 10)

assert(allZero(tZero1))
assert(allZero(tZero2))
assert(allZero(tZero3))

tZero1[1] = 1
tZero2[1][1] = 1
tZero3[1][1][1] = 2

assert(not allZero(tZero1))
assert(not allZero(tZero2))
assert(not allZero(tZero3))

print('ok allZero')

