-- kernelEpanechnikovQuadraticKnn2_test.lua
-- unit test

require 'assertEq'
require 'kernelEpanechnikovQuadraticKnn2'
require 'makeVp'

local vp = makeVp(0, 'tester')

local distances = torch.Tensor{1,2,3,4}
vp(1, 'distances', distances)
local k = 3

local weights, errorMsg = kernelEpanechnikovQuadraticKnn2(distances, k)
assert(not errorMsg)
local expected = torch.Tensor{.75 * 8 / 9, .75 * 5 / 9, 0, 0}
assertEq(weights, expected, .0001)

local distances = torch.Tensor{4,3,2,1}
local weights, errorMsg = kernelEpanechnikovQuadraticKnn2(distances, k)
assert(not errorMsg)
local expected = torch.Tensor{0, 0, .75 * 5 /9, .75 * 8 / 9}
assertEq(weights, expected, .0001)

local distances = torch.Tensor{0,0,0,0}
local weights, errorMsg = kernelEpanechnikovQuadraticKnn2(distances, k)
assert(errorMsg == 'kth closest has zero distance')

print('ok kernelEpanechnikovQuadraticKnn2')
