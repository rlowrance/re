-- printTableVariable.lua
-- print value of variable in current function

require 'printTableValue'
require 'StackFrame'

function printTableVariable(variableName)
   assert(variableName ~= nil, 'missing variableName argument')
   assert(type(variableName) == 'string', 'must supply a variable name in a string')
   local sf = StackFrame('caller')
   local table = sf:variableValue(variableName)
   assert(type(table) == 'table', variableName .. ' is not a table in the current function')
   printTableValue(variableName, table)
end
