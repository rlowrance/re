-- equalTensors_test.lua
-- unit test

require 'equalTensors'
require 'makeVp'

local vp = makeVp(0, 'tester')

a = torch.Tensor{1,2,3}
b = torch.Tensor{1,2,3}
c = torch.Tensor{1,2,10}

assert(equalTensors(a,b))
assert(not equalTensors(a,c))

d = torch.Tensor{{1,2,3},{4,5,6}}
e = torch.Tensor{{1,2,3},{4,5,6}}
f = torch.Tensor{{1,2,3},{4,5,10}}

assert(equalTensors(d,e))
assert(not equalTensors(d, f))

assert(not equalTensors(a,d))

print('ok equalTensors')