-- argmax_test.lua
-- unit test for argmax

require 'argmax'
require 'ifelse'
require 'makeVp'
require 'Timer'

local vp = makeVp(0, 'tester')

-- Don't set the random seed, since we make multiple runs to check the timing
--torch.manualSeed(123)

local v = torch.Tensor{1,-100,1.000001,0}
assert(argmax1(v) == 3)
assert(argmax2(v) == 3)
assert(argmax(v) == 3)


local function run(version, f, nIterations, nDimensions)
   local v = torch.rand(nDimensions)

   vp(2, 'run version', version, 'run nDimensions', nDimensions)
   local timer = Timer()
   for i = 1, nIterations do
      local maxIndex = argmax1(v)
   end
   vp(1, string.format('version %d nIterations %d nDimensions %d cpu secs %f',
                     version, nIterations, nDimensions, timer:cpu()))
end

local checkTiming = false
if checkTiming then
   for _, nDimensions in ipairs({1e1, 1e2, 1e3, 1e6}) do
      local nIterations = math.floor(1e7 / nDimensions)
      for _, version in ipairs({1,2}) do
         local f = ifelse(version == 1, argmax1, argmax2)
         run(version, f, nIterations, nDimensions)
      end
   end
end

print('ok')



