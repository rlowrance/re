-- kroneckerProduct_test.lua
-- unit test

require 'assertEq'
require 'kroneckerProduct'
require 'makeVp'
require 'Timer'
require 'torch'

local vp = makeVp(0, 'tester')

local t1 = torch.Tensor{1, 2}
local t2 = torch.Tensor{3, 4, 5}

vp(2, 't1', t1, 't2', t2)

local kp = kroneckerProduct(t1, t2)
vp(2, 'kp', kp)

assertEq(kp, torch.Tensor{3, 4, 5, 6, 8, 10}, 0)

print('ok kroneckerProduct')

-- check alternative implementation
local kp2 = kroneckerProduct(t1, t2, 2)
assertEq(kp, kp2, 0)

-- check timing
if false then
   print('running timing tests')
   local nIterations = 100000
   local t1 = torch.rand(13)  -- 14 classes
   local t2 = torch.rand(9)   -- 9 features plus prepended 1
   
   local function check(implementation)
      local vp = makeVp(0, 'check')
      vp(1, 'implementation', implementation)
      assert(implementation)
      local timer = Timer()
      for i = 1, nIterations do
         local kp = kroneckerProduct(t1, t2, implementation)
      end
      local totalCpu = timer:cpu()
      vp(0, string.format('implementation %d avg cpu %f', 
                          implementation, 
                          totalCpu / nIterations))
   end

   local nImplementations = 2
   for implementation = 1, nImplementations do
      check(implementation)
   end
   -- implementation 2 takes about half the CPU as does implemenation 1

end
