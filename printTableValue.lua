-- printTableValue.lua
-- print value of variable in current function

require 'StackFrame'

function printTableValue(table)
   assert(table ~= nil, 'missing table value argument')
   assert(type(table) == 'table', tostring(table) .. ' is a ' .. type(table) .. ' , not a table')

   local functionName = StackFrame('caller'):functionName()

   local function printAtLevel(table, level)
      local formatString = 'function %s ' .. string.rep('.', level) .. '%s = %s'
      for k, v in pairs(table) do
         print(string.format(formatString, functionName, tostring(k), tostring(v)))
         if type(v) == 'table' then
            printAtLevel(v, level + 1)
         end
      end
   end
   
   printAtLevel(table, 1)
end
