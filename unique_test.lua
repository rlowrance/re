-- unique_test.lua

require 'makeVp'
require 'unique'

local verbose = 0
local vp = makeVp(verbose, 'unique_test')

local t1 = {1,2,'ab', 2, 'cd', 'ab'}
local u1 = unique(t1)
vp(1, 'u1', u1)
assert(#u1 == 4)

local t2 = {'abc',
            'def', 
            x = 'abc', 
            y = 'ghi', 
            'abc'}
local u2 = unique(t2)
vp(1, 'u2', u2)
assert(#u2 == 3)

local t3 = torch.Tensor{1, 2, -3, 3, 2, 1}
local u3 = unique(t3)
vp(1, 'u3', u3)
assert(#u3 == 4)

local t4 = torch.Tensor{{1}, {2}, {3}, {-3}, {2}, {1}} -- n x 1
local u4 = unique(t4)
vp(1, 'u4', u4)
assert(#u4 == 4)


print('ok unique')
