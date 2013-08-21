-- One.lua
-- prevent multiple executions using a lock file
-- ref: http://stackoverflow.com/questions/14204108/preventing-multiple-executions-of-a-lua-script
-- ref: http://stackoverflow.com/questions/1034334/easiest-way-to-make-lua-script-wait-pause-sleep-block-for-a-few-seconds

require 'makeVp'
require 'validateAttributes'

-- API overview
if false then
   lock = Lock('path/to/lockfile')

   if lock:acquire() then  -- return true if lock acquired, otherwise false
      -- do protected work
      lock:release()
   else
      -- could not acquire lock
   end

   -- attempt maxTries times to acquire the lock, waiting nSeconds between
   -- each try
   if not lock:acquireOrWait(nSeconds, maxTries) then
      error('could not acquire lock')
   end
   -- do protected work
   lock:release()
end

local Lock = torch.class('Lock')

-- constructor
function Lock:__init(pathToLockFile)
   local vp = makeVp(1, 'Lock:__init')
   validateAttributes(pathToLockFile, 'string')
   self.pathToLockFile = pathToLockFile
   vp(1, 'self', self)
end

-- attempt to acquire the lock
-- RETURNS
-- boolean : true, if the lock was acquired
--           false, if the lock was not acquired
function Lock:acquire()
   local vp = makeVp(0, 'Lock:acquire')
   local cmd = 'mkdir ' .. self.pathToLockFile .. ' >/dev/null 2>&1'
   vp(2, 'cmd', cmd)
   local ok, s, n = os.execute(cmd)
   vp(2, 'ok', ok, 's', s, 'n', n)
   if ok == 0 then
      -- created the directory (aka, the lockfile)
      return true
   else
      return false
   end
end

-- release the lock, if it is held, and return true
-- if lock is not held, error
-- RETURNS true
function Lock:release()
   local vp = makeVp(0, 'Lock:release')
   local cmd = 'rmdir ' .. self.pathToLockFile
   vp(2, 'cmd', cmd)
   local ok, s, n = os.execute(cmd)
   vp(2, 'ok', ok, 's', s, 'n', n)
   if ok == 0 then
      return true
   else
      error('failed to remove lock directory')
   end
end

-- acquire the lock and return true
-- if lock cannot be acquired immediately, wait for nSeconds, then retry
-- ARGS
-- nSeconds : number of seconds to wait between tries
-- maxTries : number of tries before giving up
-- RETURNS
-- boolean  : true, if lock acquired
--            false, if lock not acquired
function Lock:acquireOrWait(nSeconds, maxTries)
   local vp = makeVp(0, 'Lock:acquireOrWait')
   validateAttributes(nSeconds, 'number', '>', 0)
   validateAttributes(maxTries, 'number', '>', 0)
   local n = 0
   local tries = 0
   repeat 
      cmd = 'sleep ' .. tostring(n)
      vp(2, 'cmd', cmd)
      os.execute(cmd)
      local attemptOk = self:acquire()
      trieds = tries + 1
      n = nSeconds
   until attemptOk or tries > maxTries
   if attemptOk then
      return true
   else
      return false
   end
end
