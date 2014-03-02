-- printVariable.lua
-- print value of variable in current function

require 'ifelse'
require 'StackFrame'

function printVariable(variableName)
   assert(variableName ~= nil, 'missing variableName argument')
   local sf = StackFrame('caller')
   local functionName = sf:functionName()
   local value = tostring(sf:variableValue(variableName))
   if functionName == nil then
      print(string.format('<unknown function> %s = %s', variableName, value))
   else
      print(string.format('function %s %s = %s', functionName, variableName, value))
   end
end
