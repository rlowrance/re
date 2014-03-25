-- printVariables.lua
-- print one or more variables in the local stack frame

require 'printVariable'
require 'StackFrame'

function printVariables(...)
   local sf = StackFrame('caller')
   local functionName = sf:functionName()
   local names = {...}
   for _, name in ipairs(names) do
      local value = tostring(sf:variableValue(name))
      if functionName == nil then
         print(string.format('<unknown function> %s = %s', name, value))
      else
         print(string.format('function %s %s = %s', functionName, name, value))
      end
   end
end
