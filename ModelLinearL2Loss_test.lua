-- ModelLinearL2Loss_test.lua

require 'makeVp'
require 'ModelLinearL2Loss'

local verbose = 0
local vp = makeVp(verbose)

local n = 2  -- size
local m = ModelLinearL2Loss(n)
local initialWeights = torch.Tensor(n + 1):fill(1)
m:setWeights(initialWeights)

local weights = m:getWeights()
assert(weights:nDimension() == 1)
assert(weights:size(1) == n + 1)
for i = 1, n+1 do
   assert(weights[i] == 1)
end

local inputs = torch.Tensor({2,3})
local prediction = m:predict(inputs)
assert(prediction == 1 + 2 + 3)

local target = 10
local loss, dWeights, prediction = m:ldp(inputs, target)
assert(loss == 4 * 4)
assert(dWeights:nDimension() == 1)
assert(dWeights:size(1) == 3)
vp(1, 'dWeights', dWeights)
for i = 1, 3 do
   assert(dWeights[i] == 32)
end

print('ok ModelLinearL2Loss')



