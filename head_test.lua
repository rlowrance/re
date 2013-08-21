-- head_test.lua
-- unit test for head

require 'assertEq'
require 'Dataframe'
require 'head'
require 'makeVp'

local vp = makeVp(0, 'tester')

-- type is table
local t = {1,2,3,4,5,6,7,8,9,10}
local result = head(t, 3)
assertEq(result, {1,2,3}, 0)

-- type is 1D Tensor
local t = torch.Tensor{1,2,3,4,5,6,7,8,9,10}
local result = head(t, 3)
vp(1, 'result', result)
assertEq(result, torch.Tensor{1,2,3}, 0)

-- test n > length
assertEq(head(torch.Tensor{1,2}, 3), torch.Tensor{1,2}, 0)

-- type is 2D Tensor
local t = torch.Tensor{{1,2,3},{11,12,13},{21,22,23}}
local result = head(t, 2)
assertEq(result, torch.Tensor{{1,2,3},{11,12,13}}, 0)

assertEq(head(t, 4), t, 0)

-- type is Dataframe
local values = {x = {1,2,3}, y = {'abc', 'def', 'ghi'}}
local levels = {x = {'one', 'two', 'three'}}
local df = Dataframe{values=values, levels=levels}
vp(1, 'df', df)
local result = head(df, 2)
vp(1, 'result', result)
assertEq(result:column('x'), {1,2}, 0)
assertEq(result:column('y'), {'abc', 'def'}, 0)
assert(result:kind('x') == 'factor')
assert(result:level('x', 2) == 'two')



print('ok head')
