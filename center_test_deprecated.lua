-- center_test.lua
-- unit test

require 'assertEq'
require 'center'
require 'makeVp'
require 'standardize'

local verbose = 2
local vp = makeVp(verbose, 'tester')

local t = torch.rand(5,3)
local s, means, stds = standardize(t)
vp(2, 't', t, 's', s, 'means', means, 'stds', stds)

local c = center(t, means, stds)
assertEq(s, c, 0)

local t2 = torch.Tensor({1,2,3})
local c2 = center(t2, torch.Tensor{1,1,1}, torch.Tensor{2,2,2})
vp(2, 't2', t2, 'c2', c2)
assertEq(c2, torch.Tensor{0, .5, 1}, 0)

print('ok center')

