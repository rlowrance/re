-- printValue.lua
-- print value of variable in current function

require 'StackFrame'

function printValue(variableName)
   assert(variableName ~= nil, 'missing variableName argument')
   local sf = StackFrame('caller')
   print(string.format('function %s %s = %s', sf:functionName(), variableName, sf:variableValue(variableName)))
end
