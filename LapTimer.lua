-- LapTimer.cpu
-- accumulate wall clock and CPU time

require 'ifelse'

-- API overview
if false then
   lt = LapTimer()
   lt:lap('part 1')
   lt:lap('part 2')

   for lapname, cpuWallclock in pairs(lt:getTimes()) do
      cpu = cpuWallclock.cpu
      wallclock = cpuWallclock.wallclock
   end
end

require 'Accumulators'
require 'makeVp'

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

torch.class('LapTimer')

function LapTimer:__init(functionName, fileDescriptor)
   self.cpuAccumulators = Accumulators()
   self.wallclockAccumulators = Accumulators()
   self.timer = torch.Timer()   -- starts the timer
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

function LapTimer:lap(lapname)
   local t = self.timer:time()  -- returns t.user, t.sys, t.real
   self.cpuAccumulators:add(lapname, t.user + t.sys)
   self.wallclockAccumulators:add(lapname, t.real)
end

function LapTimer:getTimes() 
   local result = {}
   local cpus = self.cpuAccumulators:getTable()
   local wallclocks = self.wallclockAccumulators:getTable()
   for lapname, cpu in pairs(cpus) do
      result[lapname] = {
         cpu = cpu,
         wallclock = wallclocks[lapname],
      }
   end
   return result
end
   

   
