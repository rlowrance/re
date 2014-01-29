-- isTensor_test.lua
-- unit test

require 'isTensor'
require 'torch'

assert(isTensor(torch.Tensor(3)))
assert(not isTensor(nil))
assert(not isTensor(123))
assert(not isTensor(function(a) return a end))
assert(not isTensor({1,2,3}))

print('ok isTensor')

