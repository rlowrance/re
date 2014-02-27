-- LapTimer_test.lua
-- unit test

require 'makeVp'
require 'LapTimer'
require 'printTableValue'
require 'Timer'

local vp = makeVp(0, 'tester')

local lt = LapTimer()

lt:lap('one')
lt:lap('two')
lt:lap('one')

local times = lt:getTimes()
for lapname, times in pairs(lt:getTimes()) do
   vp(2, 'lapname', lapname, 'times', times)
   assert(lapname == 'one' or lapname == 'two')
   assert(times.cpu >= 0)
   assert(times.wallclock >= 0)
end
 
if false then
   print('determining overhead in the timing mechanism')

   local function doNothing(nIterations)
      for i = 1, nIterations do
      end
   end

   local justLapLapTimer = LapTimer()
   local function justLap(nIterations)
      for i = 1, nIterations do
         justLapLapTimer:lap('justLap')
      end
   end
   
   local function getTimes(f, nIterations)
      local timer = Timer()
      f(nIterations)
      local cpu, wallclock = timer:cpuWallclock()
      return {cpu = cpu, wallclock = wallclock}
   end

   local nIterations = 100000

   print('nIterations', nIterations)
   print('average times per iteration')

   local nothingTimes = getTimes(doNothing, nIterations)
   printTableValue('nothingTimes', nothingTimes)
   print('nothingTimes', nothingTimes)
   local nothingCpu = nothingTimes.cpu / nIterations
   local nothingWallclock = nothingTimes.wallclock / nIterations

   print(string.format('do nothing: cpu %17.15f wallclock %17.15f', nothingCpu, nothingWallclock))

   local justLapTimes = getTimes(justLap, nIterations)
   local justLap cpu = justLapTimes.cpu / nIterations - nothingCpu
   local justLapWallclock = justLapTimes.wallclock / nIterations - nothingWallclock
   print(string.format('just lap  : cpu %17.15f wallclock %17.15f', nothingCpu, nothingWallclock))
end


print('ok LapTimer')

