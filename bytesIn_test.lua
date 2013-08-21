-- bytesIn_test.lua
-- unit test

require 'bytesIn'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

vp(1, '1D', bytesIn(torch.Tensor(12)))
vp(1, '2D', bytesIn(torch.Tensor(53,78)))

assert(16 == bytesIn(123))
print('ok bytesIn')