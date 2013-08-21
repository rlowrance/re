-- unit test

require 'makeVp'
require 'viewAsColumnVector'

local vp = makeVp(2, 'tester')

local t = torch.Tensor{10, 20, 30}

local v = viewAsColumnVector(t)

assert(v:dim() == 2)
assert(v:size(1) == t:size(1))
assert(v:size(2) == 1)

assert(v[1][1] == 10)
assert(v[2][1] == 20)
assert(v[3][1] == 30)

v[2][1] = 200
assert(t[2] == 200)

t[3] = 300
assert(v[3][1] == 300)

print('ok viewAsColumnVector')

