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
   timer = Timer('function name', io.stderr)
   timer:lap('part 1')
   timer:lap('part 2')
   timer:write()  -- write all CPU and Wallclock lap times
end

require 'makeVp'
require 'validateAttributes'

torch.class('Timer')

function Timer:__init(functionName, fileDescriptor)
   self.timer = torch.Timer()
   self.functionName = functionName
   self.fileDescriptor = fileDescriptor
   self.lapNames = {}
   self.cpuTimes = {}
   self.wallclockTimes = {}
end

-- save cpu and wallclock time; then reset
function Timer:lap(lapName)
   --local vp = makeVp(2, 'Timer:lap')
   --vp(1, 'self', self, 'lapName', lapName)
   validateAttributes(lapName, 'string')
   table.insert(self.lapNames, lapName)
   table.insert(self.cpuTimes, self:cpu())
   table.insert(self.wallclockTimes, self:wallclock())
   self:reset()  -- restart the clock
end

-- verbose write cpu and wallclock time
function Timer:write()
   if self.functionName == nil then
      error('did not supply a function name')
   end
    
   if self.fileDescriptor == nil then
      error('did not supply a file descriptor')
   end
   
   for i, lapName in ipairs(self.lapNames) do
      io.write(self.functionName .. ' ' ..
               lapName .. ' ' ..
               ' cpu ' .. tostring(self.cpuTimes[i]) ..
               ' wallclock ' .. tostring(self.wallclockTimes[i]) ..
               '\n')
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
   

   
