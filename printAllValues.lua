-- printAllValues.lua
-- print value of variable in current function

require 'StackFrame'

function printAllValues()
   local sf = StackFrame('caller')
   print(string.format('function %s variables', sf:functionName()))
   for k, v in pairs(sf.values) do
      print(string.format(' %s = %s', k, v))
   end
end
