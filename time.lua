-- time.lua
-- run function and return cpu and wall clock seconds
-- ARGS:
-- options : optional object, default 'cpu'
--           what values to report, choices are in {'cpu', 'wallclock', 'both'}
-- f       : function to call
-- ...     : arguments to f
-- returns:
-- time1   : first time value requested
-- time2   : second time value requested
-- result1 : first results from f()
-- result2 : second result from f()
-- ...

require 'makeVp'
require 'printTableValue'
require 'Timer'

-------------------------------------------------------------------------------
-- MAIN FUNCTION
-------------------------------------------------------------------------------
function time(options, f, ...)
   local vp, verboseLevel = makeVp(0, 'time')
   vp(1, 'options', options, 'f', f, '...', ...)

   local args = {...}
   if verboseLevel > 0 then printTableValue('args', args) end
   
   if type(options) == 'function' then
      return time('cpu', options, f, ...)

   elseif options == nil then
      return time('cpu', f, ...)

   elseif options == 'cpu' then
      local timer = Timer()
      local r1, r2, r3, r4, r5, r6, r7, r8, r9 = f(...)
      return timer:cpu(), r1, r2, r3, r4, r5, r6, r7, r8, r9

   elseif options == 'wallclock' then
      local timer = Timer()
      local r1, r2, r3, r4, r5, r6, r7, r8, r9 = f(...)
      return timer:wallclock(), r1, r2, r3, r4, r5, r6, r7, r8, r9

   elseif options == 'both' then
      local timer = Timer()
      local r1, r2, r3, r4, r5, r6, r7, r8, r9 = f(...)
      local cpu, wallclock = timer:cpuWallclock()
      return cpu, wallclock, r1, r2, r3, r4, r5, r6, r7, r8, r9

   else
      error('bad option: ' .. tostring(option))
   end
end
