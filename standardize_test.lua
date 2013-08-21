-- center_test.lua
-- unit test

require 'assertEq'
require 'standardize'
require 'makeVp'

vp = makeVp(0, 'tester')

-- test sequence
seq = {2,4,4,4,5,5,7,9}  -- from Wikipedia at "standard deviation"

standardized, mean, stddev = standardize(seq)
vp(1, 'standardized', standardized)
vp(1, 'mean', mean)
vp(1, 'stddev', stddev)

assert(mean == 5)
assert(stddev == 2)

assert(standardized[1] == -1.5)
assert(standardized[2] == -0.5)
assert(standardized[5] == 0)
assert(standardized[7] == 1)
assert(standardized[8] == 2)

-- test 1D Tensor
tensor = torch.Tensor{{1, 2, 3}, {11, 12, 13}}
s, m, sd = standardize(tensor)
assertEq(standardize(tensor[1], m, sd), s[1], 0)

-- test 2D tensor

tensor = torch.Tensor{{1, 2, 3}, {11, 12, 13}}
s, m, sd = standardize(tensor)
vp(1, 's', s)
vp(1, 'm', m)
vp(1, 'sd', sd)
assertEq(m, torch.Tensor{{6, 7, 8}}, 0)
assertEq(sd, torch.Tensor{{5, 5, 5}}, 0)
assertEq(s, torch.Tensor{{-1, -1, -1}, {1, 1, 1}}, 0)

-- test re-use of means and standard deviations

local t = torch.rand(5,3)
local s, means, stds = standardize(t)
vp(2, 't', t, 's', s, 'means', means, 'stds', stds)

local c = standardize(t, means, stds)
assertEq(s, c, 0)

local t2 = torch.Tensor{{1,2,3}}
local c2 = standardize(t2, torch.Tensor{{1,1,1}}, torch.Tensor{{2,2,2}})
vp(2, 't2', t2, 'c2', c2)
assertEq(c2, torch.Tensor{{0, .5, 1}}, 0)


print('ok standardize')