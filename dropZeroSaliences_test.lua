-- dropZeroSaliences_test.lua
-- unit test and timing test

require 'dropZeroSaliences'
require 'makeVp'
require 'Random'
require 'time'

local vp, verboseLevel = makeVp(0, 'tester')
local runTimingTests = true
local runTimingTests = false

-- unit test driver
local function unitTest(implementation)
   local vp = makeVp(0, 'unitTest')
   vp(1, 'implementation', implementation)

   local nSamples = 10
   local nFeatures = 3

   local X = torch.rand(nSamples, nFeatures)
   local y = torch.rand(nSamples)
   local s = torch.Tensor{0, 1, 0, 0, .1, 0, 0 ,0 , 0, .3}

   local nNonZero = 3
   vp(1, 'nNonZero', nNonZero)

   local newX, newY, newS = dropZeroSaliences(X, y, s, implementation)

   vp(2, 's', s, 'newS', newS)
   assert(newS:dim() == 1)
   assert(newS:size(1) == nNonZero)
   assert(newS[1] == 1)
   assert(newS[2] == .1)
   assert(newS[3] == .3)

   vp(2, 'X', X, 'newX', newX)
   assert(newX:dim() == 2)
   assert(newX:size(1) == nNonZero)
   assert(newX:size(2) == nFeatures)

   vp(2, 'Y', Y, 'newY', newY)
   assert(newY:dim() == 1)
   assert(newY:size(1) == nNonZero)

   -- check that right samples were retained
   local newIndex = 0
   for i = 1, nSamples do
      if s[i] ~= 0 then
         newIndex = newIndex + 1
         for j = 1, nFeatures do
            assert(X[i][j] == newX[newIndex][j])
         end
         assert(y[i] == newY[newIndex])
         assert(s[i] == newS[newIndex])
      end
   end
end

-- unit and timing test
-- 1. Make sure each implementation gives correct answer
-- 2. Pick the fastest implementation
local nImplementations = 2

-- unit tests
for implementation = 1, nImplementations do
   unitTest(implementation)
end

-- timing test driver
local function makeTimingTestData()
   -- configure a typical test case
   local nSamples = 650000
   local nFeatures = 8
   local k = 60

   local X = torch.rand(nSamples, nFeatures)
   local y = torch.rand(nSamples)

   local s = torch.Tensor(nSamples):zero()
   local nonZeroIndices = Random():integer(k, 1, nSamples)
   for i = 1, k do
      s[nonZeroIndices[i]] = 1
   end

   return X, y, s
end


-- timing test

local function timingTest()
   local X, y, s = makeTimingTestData()
   local nIterations = 200

   local cpu = {}
   local wallclock = {}
   vp(1, 'starting timing tests; nIterations', nIterations)
   for implementation = 1, nImplementations do
      collectgarbage()
      for iteration = 1, nIterations do
         local cpuSecs, wallclockSecs = time('both', dropZeroSaliences, X, y, s, implementation)
         cpu[implementation] = (cpu[implementation] or 0) + cpuSecs
         wallclock[implementation] = (wallclock[implementation] or 0) + wallclockSecs
      end
   end
   vp(2, 'cpu', cpu, 'wallclock', wallclock)

   for implementation = 1, nImplementations do
      print(string.format('implementation %d avg cpu %f avg wallclock %f',
                          implementation,
                          cpu[implementation] / nIterations,
                          wallclock[implementation] / nIterations))
   end
end

if runTimingTests then
   timingTest()
end




print('ok dropZeroSaliences')
