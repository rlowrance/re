-- variableValue.lua
-- return value of variable in current stack frame
function variableValue(variableName)
   local stackLevel = 2 -- level of caller to this function

   local localIndex = 0
   repeat 
      localIndex = localIndex + 1
      local name, value = debug.getlocal(stackLevel, localIndex)
      if name == variableName then
         return value
      end
   until name == nil
   
   return nil  -- if name is not present in frame, value is nil
end
