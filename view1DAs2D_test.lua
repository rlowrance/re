-- viewAs2D_test.lua
-- unit test

require 'assertEq'
require 'makeVp'
require 'view1DAs2D'

local verbose = 2
local vp = makeVp(verbose, 'tester')

local t = torch.Tensor{1,2,3}

local view = view1DAs2D(t, 5)
assert(view:dim() == 2)
assert(view:size(1) == 5)
assert(view:size(2) == 3)

for row = 1, 5 do
   assertEq(view[row], t, 0)
end

print('ok view1DAs2D')