-- printTableValua.lua
-- print value of a table


function printTableValue(variableName, tableValue)
   local function printTableNameValue(variableName, tableValue)
      for k, v in pairs(tableValue) do
         print(string.format('%s.%s = %s', variableName, tostring(k), tostring(v)))
         if type(v) == 'table' then
            printTableValue(variableName .. '.' .. tostring(k), v)
         end
      end
   end

   if type(variableName) == 'string' and type(tableValue) == 'table' then
      printTableNameValue(variableName, tableValue)
   elseif type(variableName) == 'table' and type(value) == 'nil' then
      printTableNameValue('', variableName)
   else
      error('calling sequence is printTableValue(variableName, tableValue) or printTableValue(tableValue)')
   end
end
