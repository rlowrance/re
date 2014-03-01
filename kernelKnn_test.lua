-- kernelKnn_test.lua
-- unit test

require 'kernelKnn'
require 'makeVp'

local vp = makeVp(0, 'tester')

local distances = torch.Tensor{4,2,3,1}

local function k(n)
   return kernelKnn(distances, n)
end

local function assertEqualOne(t, shouldBeOne)
   local expectOne = {}
   for _, shouldBe in ipairs(shouldBeOne) do
      expectOne[shouldBe] = true
   end

   for i = 1, t:size(1) do
      if expectOne[i] then
         assert(t[i] == 1)
      else
         assert(t[i] == 0)
      end
   end
end

assertEqualOne(k(1), {4})
assertEqualOne(k(2), {2,4})
assertEqualOne(k(3), {2,3,4})
assertEqualOne(k(4), {1,2,3,4})

print('ok kernelKnn')
