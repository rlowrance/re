-- printTableValua.lua
-- print value of a table


-- ARGS
-- variableName : optional string, name of variable holding a table value
-- tableValue   : table
function printTableValue(variableName, tableValue)

   local function printField(tableName, fieldName, fieldValue)
      assert(fieldValue ~= nil)
      print(string.format('%s.%s = %s', tableName, fieldName, tostring(fieldValue)))
   end

   local function printStorage(tableName, fieldName, value, torchTypename)
      printField(tableName, fieldName, torchTypename .. ' size ' .. value:size())
   end

   local function printTensor(tableName, fieldName, value, torchTypename)
      local sizes = value:size()
      local shape = torchTypename .. ' size '
      for i = 1, #sizes do
         if i == 1 then
            shape = shape .. ' ' .. tostring(sizes[i])
         else
            shape = shape .. ' x ' .. tostring(sizes[i])
         end
      end
      printField(tableName, fieldName, shape)
   end

   local function printUserdata(tableName, fieldName, value)
      local torchTypename = torch.typename(value)
      if torchTypename ~= nil and string.sub(torchTypename, -6) == 'Tensor' then
         -- found a Tensor
         printTensor(tableName, fieldName, value, torchTypename)
      elseif torchTypename ~= nil and string.sub(torchTypename, -7) == 'Storage' then
         -- found a Storage
         printStorage(tableName, fieldName, value, torchTypename)
      else
         -- found either non-torch userdata or non-Tensor torch data
         printField(tableName, fieldName, value)
      end
   end

   local function printTableNameValue(tableName, tableValue)
      -- sort the keys
      local keysSorted = {}
      for key in pairs(tableValue) do
         table.insert(keysSorted, {tostring(key), key})
      end

      local function compare(a, b)
         return a[1] < b[1]  -- sort on string version of key
      end

      table.sort(keysSorted, compare)

      -- print keys in their sorted order
      for _, key in ipairs(keysSorted) do
         -- parse the key, which is a sequence of length 2
         local fieldName = key[1]
         local value = tableValue[key[2]]

         local valueType = type(value)
         --print('fieldName', fieldName, 'value', value, 'valueType', valueType)

         if valueType == 'userdata' then
            printUserdata(tableName, fieldName, value)
         elseif valueType == 'table' then
            printTableValue(tableName .. '.' .. fieldName, value)
         else
            printField(tableName, fieldName, value)
         end
      end
   end

   local function errorBadType(tableValue)
      error(string.format('tableValue is type %s, not table', type(tableValue)))
   end

   -- handle the first arg, which is optional so that f(b) --> f('', b)
   -- also type check arguments
   if type(variableName) == 'string' then
      if type(tableValue) == 'table' then
         printTableNameValue(variableName, tableValue)
      else
         errorBadType(tableValue)
      end
   elseif type(variableName) == 'table' then
      if type(tableValue) == nil then
         printTableNameValue('', tableValue)
      else
         errorBadType(tableValue)
      end
   else
      error('calling sequence is printTableValue(variableName, tableValue) or printTableValue(tableValue)')
   end
end
