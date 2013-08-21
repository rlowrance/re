-- viewAdditionalRows_test.lua
-- unit test

require 'assertEq'
require 'makeVp'
require 'viewAdditionalRows'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local t = torch.Tensor{{1,2,3}}
vp(1, 't', t)

local view = viewAdditionalRows(t, 5)
vp(1, 'view', view)
assert(view:dim() == 2)
assert(view:size(1) == 5)
assert(view:size(2) == 3)

for row = 1, 5 do
   assertEq(view[row], t[1], 0)
end

print('ok viewAdditionalRows')