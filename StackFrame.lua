-- StackFrame.lua
-- info from stack frames

if false then
   -- API overview
   sf = StackFrame('caller')
   sf:functionName() 
   sf:variableValue()
end

require 'ifelse'
require 'makeVp'

torch.class('StackFrame')

function StackFrame:__init(whichFrame)
   local vp, verboseLevel = makeVp(0, 'StackFrame:__init')

   self.stackLevel = nil
   if type(whichFrame) == 'number' then
      self.stackLevel = whichFrame
   elseif whichFrame == 'caller' then
      self.stackLevel = 5
   else
      error('invalid whichFrame = ' .. tostring(whichFrame))
   end
   
   self.info = debug.getinfo(self.stackLevel)

   if verboseLevel > 0 then
      for k, v in pairs(self.info) do
         vp(1, 'self.info.' .. k, tostring(v))
      end
   end
   
   self.values = {}
   local localIndex = 0
   repeat
      localIndex = localIndex + 1
      local name, value = debug.getlocal(self.stackLevel, localIndex)
      if name == nil  then
         break
      end
      if localIndex > 100 then
         break
      end
      self.values[name] = value
   until false

   if verboseLevel > 0 then
      for k, v in pairs(self.values) do
         vp(1, 'self.values.' .. k, tostring(v))
      end
   end
end

function StackFrame:functionName()
   return self.info.name
end

function StackFrame:variableValue(variableName)
   return self.values[variableName]
end
   
