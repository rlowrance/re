-- Timer.cpu
-- measure wall clock or CPU time

-- API overview
if false then
   timer = Timer()

   timer:wallclock()     -- cumulative Wall Clock
   timer:cpu()           -- user + system CPU
   timer:cpuWallclock()  -- both at once
   timer:user()          -- just user CPU
   timer:system()        -- just system CPU

   timer:reset()         -- restart from 0
end

torch.class('Timer')

function Timer:__init()
   self.timer = torch.Timer()
end

function Timer:reset()
   self.timer:reset()
end

function Timer:wallclock()
   return self.timer:time().real
end

function Timer:cpu()
   local t = self.timer:time()
   return t.user + t.sys
end

function Timer:cpuWallclock()
   local t= self.timer:time()
   return t.user + t.sys, t.real
end

function Timer:user()
   return self.timer:time().user
end

function Timer:system()
   return self.timer:time().sys
end
   

   
