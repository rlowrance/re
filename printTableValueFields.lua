-- printTableValueFields(tableName, tableValue, sequenceOfFields).lua

-- ARGS
-- tableName            : optional string
-- tableVallue          : table
-- sequenceOfFieldNames : sequence of strings
function printTableValueFields(tableName, tableValue, fieldNames)

   local function getFieldNames(table)
      local fieldNames = {}
      for fieldName, fieldValue in pairs(table) do
         table.insert(fieldNames, fieldName)
      end
      return fieldNames
   end

   local function worker(tableName)
      assert(type(tableValue) == 'table')
      assert(type(fieldNames) == 'table')  -- actually a sequence
      for i, fieldName in ipairs(fieldNames) do
         local fieldValue = tableValue[fieldName]
         print(string.format('%s.%s = %s', tableName, fieldName, tostring(fieldValue)))
         if type(fieldValue) == 'table' then
            printTableValueFields(tableName .. '.' .. fieldName, fieldValue, getFieldNames(fieldValue))
         end
      end
   end

   if tableName == nil then
      return worker('', tableValue, fieldNames)
   else
      return worker(tableName, tableValue, fieldNames)
   end
end
