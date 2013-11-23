-- keyboard.lua
-- interact with keyboard.
-- The name comes from MATLAB.
-- The commands comes from the Python debugger.

if false then
   keyboard(message)
end

require 'ifelse'
require 'makeVp'
require 'torch'

local function help()
   print('a[rgs]          print args,local, and varargs of current function')
   print('d[own]          move current frame down one level (to new frame)')
   print('h[elp]          print help')
   print('i[interactive]  enter interactive mode')
   print('q[uit]          quit, return to program execution')
   print('u[p]            move current fram up one level (to older frame)')
   print('w[here]         print stack trace')
end


local function getInfo(stackLevel)
   local offset = 2
   return debug.getinfo(offset + stackLevel)
end

local function getinfo(stackLevel)
   local offset = 2
   return debug.getinfo(offset + stackLevel)
end

local function getlocal(stackLevel, index)
   local offset = 2
   return debug.getlocal(offset +stackLevel, index)
end

local function getNumberStackLevels()
   local vp = makeVp(0, 'getNumberStackLevels')
   local n = 0
   repeat
      n = n + 1
      vp(2, 'n', n, 'getinfo', debug.getinfo(n))
   until debug.getinfo(n) == nil
   n = n - 2   
   vp(1, 'n', n)
   return n
end

local function getNumberLocals(stackLevel)
   -- NOTE: number of locals includes any varargs
   local vp = makeVp(0, 'getNumberLocals')
   vp(1, 'stackLevel', stackLevel)
   local result = 1
   while debug.getlocal(stackLevel, result) ~= nil do
      result = result + 1
   end
   vp(1, 'result', result)
   return result
end

local function getNumberVarargs(stackLevel)
   local vp = makeVp(0, 'getNumberVarargs')
   vp(1, 'stackLevel', stackLevel)
   vp(2, 'info', debug.getinfo(stackLevel))
   local n = -1
   while debug.getlocal(stackLevel, n) ~= nil do
      n = n - 1
   end
   local result = math.abs(n + 1)
   vp(1, 'result', result)
   return result
end

-- print values of args, local variables, and varargs
local function args(currentStackLevel)
   local vp, verboseLevel = makeVp(0, 'args')
   vp(1, 'currentStackLevel', currentStackLevel)

   local info = debug.getinfo(currentStackLevel)
   if verboseLevel > 1 then
      for k, v in pairs(info) do
         vp(2, string.format('info[%s]=%s', tostring(k), tostring(v)))
      end
   end   

   
   -- print locals and varargs
   local function printVars(tag, start, step)
      local vp = makeVp(0, 'printVars')
      vp(2, 'start', start, 'step', step)
      local index = start
      while true do
         local name, value = debug.getlocal(currentStackLevel + 1, index)
         vp(2, string.format('index %d name %s value %s', index, tostring(name), tostring(value)))
         if name == nil then
            break
         end
         index = index + step
         print(tag .. ' ' .. name .. ' = ' .. tostring(value))
      end
   end
   
   printVars('local ', 1, 1)
   printVars('vararg', -1, -1)

   -- print up values
   local nUps = info.nups
   for i = 1, nUps do
      local name, value = debug.getupvalue(info.func, i)
      print('up     ' .. name .. ' = ' .. tostring(value))
   end

end

local function interactive(currentLevel)
   local vp = makeVp(0, 'interactive')
   vp(1, 'currentLevel', currentLevel)
   print('enter strings to evaluted, cont to continue')
   debug.debug()
end

local function where(currentLevel)
   local vp = makeVp(0, 'where')
   vp(1, 'currentLevel', currentLevel)

   local nStackLevels = getNumberStackLevels()
   vp(2, 'nStackLevels', nStackLevels)

   --for stackLevel = nStackLevels, 3, -1 do
   local callersStackLevel = 3   
   for stackLevel = nStackLevels - 1, callersStackLevel, -1 do
      local info = debug.getinfo(stackLevel)
      --vp(3, 'stackLevel', stackLevel, 'info', info) 
      local fileName = info['short_src']
      local functionName = info['name']
      --vp(3, 'fileName', fileName)
      --vp(3, 'function', functionName)
      print(
      ifelse(
      stackLevel == currentLevel, '-->', '   ') .. 
      fileName .. '::' .. 
      ifelse(functionName, functionName, ' ')
      )  -- functionName is nil for main program
   end
   return
end

-- MAIN FUNCTION
--
-- input from keyboard: stop execution and give control to the keyboard
-- ARGS:
-- message : optional string; printed before keyboard control given, if present
-- RETURNS: nil
function keyboard(message)
   local vp, verboseLevel = makeVp(2, 'keyboard')
   if message ~= nil then
      print('keyboard : ' .. tostring(message))
   end

   local function down()
      local vp = makeVp(0, 'down')
      vp(1, 'currentStackLevel', currentStackLevel)

      currentStackLevel = math.max(3, currentStackLevel - 1)
   end

   local function up()
      local vp = makeVp(0, 'up')
      vp(1, 'currentStackLevel', currentStackLevel)

      currentStackLevel = math.min(getNumberStackLevels(), currentStackLevel + 1)
   end
   




  -- END OF LOCAL FUNCTION DEFINITIONS

   if verboseLevel > 1 then
      for level = 1, getNumberStackLevels() do
         local info = debug.getinfo(level)
         vp(2, string.format('level %d name', level), info['name'])
      end
   end

   -- interactive loop
   local lowestUserStackLevel = 3
   local currentStackLevel = lowestUserStackLevel 

   while true do -- 'q' or 'quit' command breaks out of the loop
      io.write('keyboard> ')
      io.flush()
      command = io.read()
      vp(2, 'currentStackLevel', currentStackLevel, 'command', command) 
      if command == 'q' or command == 'quit' then
         break
      elseif command == 'u' or command == 'up' then
         currentStackLevel = math.min(getNumberStackLevels(), currentStackLevel + 1)
      elseif command == 'd' or command == 'down' then
         currentStackLevel = math.max(lowestUserStackLevel, currentStackLevel - 1)
      elseif command == 'w' or command == 'where' then
         where(currentStackLevel)
      elseif command == 'a' or command == 'args' then
         args(currentStackLevel)
      elseif command == 'i' or command == 'interactive' then
         interactive(currentStackLevel)
      else
         print('?')
         help()
      end
   end
end
