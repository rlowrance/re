-- asColumnMatrix_test.lua
-- unit test

require 'asColumnMatrix'
require 'makeVp'

local verbose = 2
local vb = makeVp(verbose, 'tester')

local t1D = torch.Tensor({1,2,3})

local m = asColumnMatrix(t1D)

assert(m:dim() == 2)
assert(m:size(1) == 3)
assert(m:size(2) == 1)

assert(m[1][1] == 1)
assert(m[2][1] == 2)
assert(m[3][1] == 3)

print('ok asColumnMatrix')