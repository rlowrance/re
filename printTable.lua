-- printTable.lua
-- print value of variable in current function

require 'StackFrame'

function printTable(variableName)
   assert(variableName ~= nil, 'missing variableName argument')
   local sf = StackFrame('caller')
   local table = sf:variableValue(variableName)
   for k, v in pairs(table) do
      print(string.format('function %s %s[%s] = %s', sf:functionName(), variableName, tostring(k), tostring(v)))
   end
end
