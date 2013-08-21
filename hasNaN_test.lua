-- hasNaN_test.lua

require 'hasNaN'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local d1 = torch.Tensor{1, 2, 3}
assert(not hasNaN(d1))
d1[1] = 10 / 0
assert(not hasNaN(d1))
d1[2] = 0 / 0
assert(hasNaN(d1))

local d2 = torch.Tensor{{1,2,3},{4,5,6}}
assert(not hasNaN(d2))
d2[2][3] = 0 / 0
assert(hasNaN(d2))

print('ok hasNaN')