-- splitTensor_test.lua
-- unit test of splitTensor

require 'splitTensor'

local function vp(x)
   if false then print(x) end
end

torch.manualSeed(123)
local t = torch.rand(10,3)
local fractionTest = 0.25
vp('t'); vp(t); vp('fractionTest=' .. fractionTest)

local test, train = splitTensor(t, fractionTest)

vp('t'); vp(t)
vp('test'); vp(test)
vp('train'); vp(train)

assert(test:nDimension() == 2)
assert(test:size(1) == 3)  -- true for the particular random seed
assert(test:size(2) == 3)

assert(train:nDimension() == 2)
assert(train:size(1) == 7)
assert(train:size(2) == 3)

print('ok splitTensor')
