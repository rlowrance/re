-- printAllVariables.lua
-- print value of variable in current function

require 'StackFrame'

function printAllVariables()
   local sf = StackFrame('caller')
   print(string.format('function %s variables', sf:functionName()))
   for k, v in pairs(sf.values) do
      print(string.format(' %s = %s', tostring(k), tostring(v)))
   end
end
