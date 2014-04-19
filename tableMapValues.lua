-- tableMapValues.lua
-- apply a function to all elements of a table
function tableMapValues(table, fn)
   local result = {}
   for k, v in pairs(table) do
      if type(v) == 'table' then
         result[k] = tableMapValues(v, fn)
      else
         result[k] = fn(v)
      end
   end
   return result
end
