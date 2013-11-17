-- keyboard.lua

require 'ifelse'
require 'makeVp'

local currentStackLevel = 3  -- stack frame 0 is the stack frame of the caller of keyboard()

local function getinfo()
   local offset = 2
   return debug.getinfo(offset + currentStackFrame)
end

local function getlocal(localIndex)
   local offset = 2
   return debug.getlocal(offset + currentStackFrame, localIndex)
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
local function args()
   local vp = makeVp(0, 'args')
   vp(1, 'currentStackLevel', currentStackLevel)
   local info = debug.getinfo(currentStackLevel)
   vp(2, 'info', info)
   local nparams = info['nparams']
   local isvararg = info['isvararg']
   local nLocals = getNumberLocals(currentStackLevel)
   local nVarargs = getNumberVarargs(currentStackLevel)
   vp(2, 'nparams', nparams, 'nLocals', nLocals, 'isvararg', isvararg, 'nVarargs', nVarargs)
   
   -- print locals (including args)
   local i = 1
   while true do
      local name, value = debug.getlocal(currentStackLevel, i)
      if name == nil then
         break
      end
      print(ifelse(i <= nparams, 'arg    ', 'local  ') ..
            name ..
            ' = ' ..
            tostring(value))
      i = i + 1
   end

   -- print varargs
   local i = -1
   while true do
      local name, value = debug.getlocal(currentStackLevel, i)
      if name == nil then
         break
      end
      print('vararg ' .. tostring(-i) .. ' ' ..
            name ..
            ' = ' ..
            tostring(value))
      i = i + 1
   end
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
   

local function where()
   local vp = makeVp(0, 'where')
   vp(1, 'currentStackLevel', currentStackLevel)

   local nStackLevels = getNumberStackLevels()
   vp(2, 'nStackLevels', nStackLevels)

   for stackLevel = nStackLevels, 3, -1 do
      local info = debug.getinfo(stackLevel)
      vp(3, 'stackLevel', stackLevel, 'info', info) 
      local fileName = info['short_src']
      local functionName = info['name']
      vp(3, 'fileName', fileName)
      vp(3, 'function', functionName)
      print(ifelse(stackLevel == currentStackLevel, '-->', '   ') .. 
            fileName .. '::' .. 
            ifelse(functionName, functionName, ' '))  -- functionName is nil for main program

   end
end


local function help()
   print('a[rgs]      print args,local, and varargs of current function')
   print('c[ommands]  enter lua debugger commands; stop with cont command')
   print('d[own]      move current frame down one level (to new frame)')
   print('h[elp]      print help')
   print('q[uit]      quit, return to program execution')
   print('u[p]        move current fram up one level (to older frame)')
   print('w[here]     print stack trace')
end

-- input from keyboard: stop execution and give control to the keyboard
-- ARGS:
-- message : optional string; printed before keyboard control given, if present
-- RETURNS: nil
function keyboard(message)
   local vp = makeVp(0, 'keyboard')
   if message then
      print('keyboard : ' .. tostring(message))
   end

   local prefix = 'entering interactive model (cont command returns to program execution)' 
   
   -- build table of known commands and their implementation functions
   local known = {}
   local function setKnown(key1, key2, value)
      known[key1] = value
      known[key2] = value
   end

   setKnown('a', 'args', args)
   setKnown('d', 'down', down)
   setKnown('h', 'help', help)
   setKnown('u', 'up', up)
   setKnown('w', 'where', where)


   -- interactive loop
   local command
   repeat
      io.write('keyboard> ')
      io.flush()
      command = io.read()
      vp(2, 'currentStackLevel', currentStackLevel)
      if command == 'quit' or command == 'q' then
         break
      elseif known[command] then
         known[command]()
      else
         print('?')
         printHelp()
      end
   until command == 'quit' or command == 'q'
end
