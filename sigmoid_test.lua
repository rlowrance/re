-- sigmoid_test.lua

require 'makeVp'
require 'sigmoid'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local z = torch.Tensor{{-10, -4, -1},
                       {1, 4, 10}}

local result = sigmoid(z)
vp(1, 'result', result)

assert(result:dim() == 2)
assert(result:size(1) == 2)
assert(result:size(2) == 3)

assert(0 < result[1][1])
assert(result[1][1] < result[1][2])
assert(result[1][2] < result[1][3])
assert(result[1][3] < result[2][1])
assert(result[2][1] < result[2][2])
assert(result[2][2] < result[2][3])


print('ok sigmoid')