-- distancesEuclidean_test.lua

require 'distancesEuclidean'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose)

local inputs = torch.Tensor( {{1,2},{3,4},{5,6}})
local query = torch.Tensor({2,1})

local result = distancesEuclidean(inputs, query)
assert(result[1] == math.sqrt(1 + 1))
assert(result[2] == math.sqrt(1 + 9)) -- fix me
assert(result[3] == math.sqrt(9 + 25))

print('ok distancesEuclidean')

