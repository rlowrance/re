-- printTableValua.lua
-- print value of a table

-- ARGS
-- variableName : optional string, name of variable holding a table value
-- tableValue   : table
-- file         : optional open file, default is io.stdout
function printTableValue(variableName, tableValue, file)

   -- create optional args

   -- ptv(table) --> ptv ('', table, io.stdout)
   if type(variableName) == 'table' and tableValue == nil and file == nil then
      return printTableValue('', variableName, io.stdout)

   -- ptv('name', table) --> ptv('name', table, io.stdout)
   elseif type(variableName) == 'string' and type(tableValue) == 'table' and file == nil then
      return printTableValue(variableName, tableValue, io.stdout)
   
   -- ptv(table, file) --> ptv('', table, file)
   elseif type(variableName) == 'table' and tableValue ~= nil then
      return printTableValue('', variableName, tableValue)
   end

   local function printField(tableName, fieldName, fieldValue, file)
      assert(fieldValue ~= nil)
      file:write(string.format('%s.%s = %s', tableName, fieldName, tostring(fieldValue)))
      file:write('\n')
   end

   local function printStorage(tableName, fieldName, value, torchTypename, file)
      printField(tableName, fieldName, torchTypename .. ' size ' .. value:size(), file)
   end

   local function printTensor(tableName, fieldName, value, torchTypename, file)
      local sizes = value:size()
      local shape = torchTypename .. ' size '
      for i = 1, #sizes do
         if i == 1 then
            shape = shape .. ' ' .. tostring(sizes[i])
         else
            shape = shape .. ' x ' .. tostring(sizes[i])
         end
      end
      printField(tableName, fieldName, shape, file)
   end

   local function printUserdata(tableName, fieldName, value, file)
      local torchTypename = torch.typename(value)
      if torchTypename ~= nil and string.sub(torchTypename, -6) == 'Tensor' then
         -- found a Tensor
         printTensor(tableName, fieldName, value, torchTypename, file)
      elseif torchTypename ~= nil and string.sub(torchTypename, -7) == 'Storage' then
         -- found a Storage
         printStorage(tableName, fieldName, value, torchTypename, file)
      else
         -- found either non-torch userdata or non-Tensor torch data
         printField(tableName, fieldName, value, file)
      end
   end

   local function printNameValueFile(tableName, tableValue, file)
      -- sort the keys
      local keysSorted = {}
      for key in pairs(tableValue) do
         table.insert(keysSorted, {tostring(key), key})
      end

      if #keysSorted == 0 then
         print(tableName .. ' = {}')
         return
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
            printUserdata(tableName, fieldName, value, file)
         elseif valueType == 'table' then
            printTableValue(tableName .. '.' .. fieldName, value, file)
         else
            printField(tableName, fieldName, value, file)
         end
      end
   end

   -- tupe check args and call driver
   if type(variableName) ~= 'string' then
      error(string.format('variableName is type %s, not string', type(variableName)))
   end

   if type(tableValue) ~= 'table' then
      error(string.format('tableValue is type %s, not table', type(tableValue)))
   end

   if file == nil then
      error('file is nil, not an open file handle')
   end

   return printNameValueFile(variableName, tableValue, file)
end
