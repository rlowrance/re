-- softmaxes_test.lua
-- unit test

require 'assertEq'
require 'makeVp'
require 'softmaxes'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- test 1D input
local v = torch.Tensor{1,2,3}
local sms = softmaxes(v)
vp(1, 'sms', sms)

local sum = math.exp(1) + math.exp(2) + math.exp(3)
vp(2, 'sum', sum)

assertEq(sms, 
         torch.Tensor{math.exp(1) / sum,
                      math.exp(2) / sum,
                      math.exp(3) / sum},
         .0001)

-- test n x 1 input
local v = torch.Tensor{{1}, {2}, {3}}
local sms = softmaxes(v)
assertEq(sms,
         torch.Tensor{{math.exp(1)/sum},
                      {math.exp(2)/sum},
                      {math.exp(3)/sum}},
         .0001)

-- test overflow
local v = torch.Tensor{731, 154, 335, 0} -- failed example
local sms = softmaxes(v)
vp(1, 'sms', sms)
assertEq(sms, torch.Tensor{1, 0, 0, 0}, 0)  -- exact result

print('ok softmaxes')