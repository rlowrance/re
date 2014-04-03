-- tensorViewPrefix_test.lua
-- unit test

require 'makeVp'
require 'tensorViewPrefix'

local tDouble = torch.Tensor({1,2,3})
local function test(t)
   local view = tensorViewPrefix(t, 2)
   assert(view:nDimension() == 1)
   assert(view:size(1) == 2)
   assert(view[1] == t[1])
   assert(view[2] == t[2])
end

test(torch.Tensor({1,2,3}))
test(torch.LongTensor({1,2,3}))

print('ok tensorViewPrefix')
