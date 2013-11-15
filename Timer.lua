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
   
   -- timing portions of a function
   timer = Timer(vp)
   timer:lap('part 1')
   timer:lap('part 2')
   timer:verbose(2, 'cpu')    -- call vp(2, 'lap name', cpuInLap) for each lap
   timer:verbose(2, 'wallclock')
end

require 'makeVp'
require 'validateAttributes'

torch.class('Timer')

function Timer:__init(vp)
   self.timer = torch.Timer()
   self.vp = vp
   self.cpuTable = {}
   self.wallclockTable = {}
end

-- save cpu and wallclock time; then reset
function Timer:lap(lapName)
   --local vp = makeVp(2, 'Timer:lap')
   --vp(1, 'self', self, 'lapName', lapName)
   validateAttributes(lapName, 'string')
   x = self:cpu()
   self.cpuTable[lapName] = self:cpu()
   self.wallclockTable[lapName] = self:wallclock()
   self:reset()
end

-- verbose print cpu time only (for now)
function Timer:verbose(verboseLevel, what)
   validateAttributes(verboseLevel, 'number')
   validateAttributes(what, 'string')
   assert(what == 'cpu' or what == 'wallclock')
   for k, v in pairs(self[what .. 'Table']) do
      self.vp(verboseLevel, what .. ' secs ' .. k, v)
   end
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
   

   
