-- TimerCpu.lua
-- easy way to determined elpased CPU timer

-- API overview
if false then
   tc = TimerCpu()  -- starts the timer

   elapsedCpuSeconds = tc:cumSeconds() -- cumulative seconds since started

   tc:reset()       -- cumulative time is now zero
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('TimerCpu')

function TimerCpu:__init()
   self:reset()
end

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function TimerCpu:reset()
   self.timer = torch.Timer()
end

function TimerCpu:cumSeconds()
   local elapsed = self.timer:time()
   return elapsed.user + elapsed.sys
end
