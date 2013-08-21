-- concatHorizontal_test.lua
-- unit test

require 'concatHorizontal'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local a = torch.Tensor{{1,2,3},
                       {4,5,6}}

local b = torch.Tensor{{100, 101},
                       {102, 103}}

local r = concatHorizontal(a, b)
vp(1, 'r', r)

assert(r:dim() == 2)
assert(r:size(1) == 2)
assert(r:size(2) == 5)
assert(r[1][1] == 1)
assert(r[2][1] == 4)
assert(r[1][5] == 101)
assert(r[2][5] == 103)

print('ok concatHorizontal')