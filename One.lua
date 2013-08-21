-- One.lua
-- BE SURE TO TEST THIS BEFORE USING
-- prevent multiple executions using a lock file
-- ref: http://stackoverflow.com/questions/14204108/preventing-multiple-executions-of-a-lua-script
-- ref: http://stackoverflow.com/questions/1034334/easiest-way-to-make-lua-script-wait-pause-sleep-block-for-a-few-seconds

require 'makeVp'
require 'validateAttributes'

-- API overview
if false then
   one = One('path/to/lockfile')

   if one:acquire() then  -- return true if lock acquired, otherwise false
      -- do protected work
      one:release()
   else
      -- could not acquire lock
   end

   one:acquireOrWait(nSeconds)  -- wait if not acquired
   -- do protected work
   one:release()
end

local One = torch.class('One')

function One:__init(pathToLockFile)
   local vp = makeVp(1, 'One:__init')
   validateAttributes(pathToLockFile, 'string')
   self.pathToLockFile = pathToLockFile
   vp(1, 'self', self)
end

function One:acquire()
   local cmd = 'mkdir ' .. self.pathToLockFile .. ' /dev/null 2>&1'
   if os.execute(cmd) then
      -- created the directory (aka, the lockfile)
      return true
   else
      return false
   end
end

function One:release()
   local cdm = 'rmdir ' .. self.pathToLockFile
   if os.execute(cmd) then
      return
   else
      error('failed to remove lock directory')
   end
end

function One:acquireOrWait(nSeconds)
   validateAttributes(nSeconds, 'number', '>', 0)
   local n = 0
   repeat 
      cmd = 'sleep ' .. tostring(n)
      os.execute(cmd)
      local attemptOk = One:acquire()
      n = nSeconds
   until attemptOk
end
