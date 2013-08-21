-- maxIndex_test.lua
-- unit test

require 'makeVp'
require 'maxIndex'

-- 1D input
local v = torch.Tensor{1, 2, 3, 20, 4}
assert(4 == maxIndex(v))

-- 2D input
local v = torch.Tensor{{1}, {2}, {3}, {20}, {-4}}
assert(4 == maxIndex(v))

print('ok maxIndex')