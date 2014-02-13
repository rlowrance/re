-- Timer.cpu
-- measure wall clock or CPU time

require 'ifelse'

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
   timer = Timer('function name', io.stderr)
   timer:lap('part 1')
   timer:lap('part 2')
   timer:write()  -- write all CPU and Wallclock lap times
   timer:write('name', openFileDescriptor) -- alternative call
end

require 'makeVp'
require 'validateAttributes'

torch.class('Timer')

function Timer:__init(functionName, fileDescriptor)
   self.timer = torch.Timer()
   self.functionName = functionName
   self.fileDescriptor = fileDescriptor
   self.cpuTimes = {}
   self.wallclockTimes = {}
end

-- save time from last lap, both cpu and wallclock time
function Timer:lap(lapName)
   local vp = makeVp(0, 'Timer:lap')
   vp(1, 'self', self, 'lapName', lapName)
   self.cpuTimes[lapName] = (self.cpuTimes[lapName] or 0) + self:cpu()
   self.wallclockTimes[lapName] = (self.wallclockTimes[lapName] or 0) + self:wallclock()
   self:reset()  -- restart clock for next lap
end


-- verbose write cpu and wallclock time
function Timer:write(name, fd)
   name = ifelse(name ~= nil, name, self.functionName)
   name = ifelse(name == nil, ' ', name)

   fd = ifelse(fd ~= nil, fd, self.fileDescriptor)
   fd = ifelse(fd == nil, io.stderr, fd)
   
   local totalCpu = 0
   local totalWallclock = 0
   local format = '%30s %30s cpu %8.6f wallclock %8.6f\n'
   for lapName, cpu in pairs(self.cpuTimes) do
      local wallclock = self.wallclockTimes[lapName]
      totalCpu = totalCpu + cpu
      totalWallclock = totalWallclock + wallclock
      fd:write(string.format(format, name, lapName, cpu, wallclock))
   end
   fd:write(string.format(format, name, 'TOTAL', totalCpu, totalWallclock))
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
   

   
