-- Timer.cpu
-- measure wall clock and CPU time
-- fascade over torch.timer, providing easier-to-remember API

require 'ifelse'

-- API overview
if false then
   timer = Timer()

   -- obtain cumulative times since the timer was created or resumed
   timer:wallclock()     -- wallclock (aka, real)
   timer:cpu()           -- user + system CPU
   timer:cpuWallclock()  -- return cpu, wallclock

   timer:user()          -- just user CPU
   timer:system()        -- just system CPU

   timer:reset()         -- restart from 0; constructing the Timer starts it

   timer:stop()          -- stop the timer
   timer:resume()        -- restart from when stopped
end

require 'makeVp'
require 'validateAttributes'

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

torch.class('Timer')

function Timer:__init(functionName, fileDescriptor)
   self.timer = torch.Timer()
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

function Timer:cpu()
   local t = self.timer:time()
   return t.user + t.sys
end

function Timer:cpuWallclock()
   local t= self.timer:time()
   return t.user + t.sys, t.real
end

function Timer:reset()
   self.timer:reset()
end

function Timer:resume()
   self.timer:resume()
end

function Timer:system()
   return self.timer:time().sys
end

function Timer:stop()
   self.timer:stop()
end

function Timer:user()
   return self.timer:time().user
end

function Timer:wallclock()
   return self.timer:time().real
end
