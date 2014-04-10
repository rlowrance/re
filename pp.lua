-- pp.lua
-- collection of pretty-print routines

if false then
   -- API overview after require 'pp'
   pp.variable('name')     -- in stack frame
   pp.variables()          -- all in stack frame
   pp.variables('a', 'b')  -- specific variables in stack frame

   pp.table('name', value)
   pp.table('name', value, openFile)

   pp.tensor('name', value)
   pp.tensor('name', value, nRows, nCols, formatString)
end

pp = {}

require 'ifelse'
require 'isTensor'
require 'makeVp'
require 'StackFrame'

-- print table value
-- ARGS
-- variableName : optional string, name of variable holding a table value
-- tableValue   : table
-- file         : optional open file, default is io.stdout
function pp.table(variableName, tableValue, file)

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

-- print tensor value
-- ARGS
-- name       : optional string, name of variable holding a table value
-- value      : table
-- maxRows    : optional integer, default value:size(1)
-- maxColumns : optional integer, default value:size(2)
-- formatString : option string used to format each number, default is '%.4g'
function pp.tensor(name, value, maxRows, maxColumns, formatString)
   local vp = makeVp(0, 'printTensorValue')
   vp(1, '******************************************')
   vp(1, 'name', name, 'value', value, 'maxRows', maxRows, 'maxColumns', maxColumns, 'formatString', formatString)
   
   local function printRow(vector, actualMaxColumns, actualFormatString)
      local nColumns = vector:size(1)
      local s = '['
      for i = 1, nColumns do
         if i > actualMaxColumns then
            s = s .. ', ...'
            break
         end
         if i > 1 then 
            s = s .. ','
         end
         s = s .. string.format(' ' .. actualFormatString, vector[i])
      end
      s = s .. ']'
      print(s)
   end

   -- return string of sizes of each dimension
   -- ex: 3 by 8
   local function sizes(tensor)
      local vp = makeVp(0, 'sizes')
      vp(1, 'tensor', tensor)

      local nDimension = tensor:nDimension()
      if nDimension == 1 then
         return tostring(tensor:size(1))
      end
         
      -- more than 1 dimension
      s = ''
      for d = 1, tensor:nDimension() do
         if d > 1 then
            s = s .. ' x '
         end
         s = s .. tostring(tensor:size(d))
      end
      vp(1, 's', s)
      return s
   end

   if false then
      -- unit test sizes()
      local t = torch.rand(10)
      local s = sizes(t)
      print(t, s)
      local t = torch.rand(3,4)
      local s = sizes(t)
      print(t, s)
      stop()
   end

   local function makeActualMaxRows(maxRows)
      if maxRows == nil then
         return 6
      else
         assert(type(maxRows) == 'number')
         return maxRows
      end
   end

   local function makeActualMaxColumns(maxColumns)
      if maxColumns == nil then
         return 6
      else
         assert(type(maxColumns) == 'number')
         return maxColumns
      end
   end
   
   local function makeActualFormatString(formatString)
      if formatString == nil then
         return '%.4g'
      else
         return formatString
      end
   end

   local function printValue1D(value, actualMaxRows, actualMaxColumns, actualFormatString)
      printRow(value, actualMaxColumns, actualFormatString)
   end

   local function printValue2D(value, actualMaxRows, actualMaxColumns, actualFormatString)
      local nRows = value:size(1)
      for i = 1, nRows do
         if i > actualMaxRows then
            print('...')
            break
         end
         printRow(value[i], actualMaxColumns, actualFormatString)
      end
   end

   local function printNameValue(name, value, maxRows, maxColumns, formatString)
      local vp = makeVp(0, 'printNameValue')
      vp(1, 'name', name, 'value', value, 'maxRows', maxRows, 'maxColumns', maxColumns)

      -- set default values for optional args
      local actualMaxRows = makeActualMaxRows(maxRows)
      local actualMaxColumns = makeActualMaxColumns(maxColumns)
      local actualFormatString = makeActualFormatString(formatString)

      assert(name)
      assert(value)
      assert(actualMaxRows)
      assert(actualMaxColumns)

      print(string.format('Tensor %s type %s size %s', name, torch.typename(value), sizes(value)))
      local nDimension = value:nDimension()
      if nDimension == 1 then
         printValue1D(value, actualMaxRows, actualMaxColumns, actualFormatString)
      elseif nDimension == 2 then
         printValue2D(value, actualMaxRows, actualMaxColumns, actualFormatString)
      else
         error('more than 2D not yet implemented')
      end
   end

   local function usage(msg)
      if msg then
         print(msg)
      end
      print('usage is printTensorValue(name, value) or printTensorValue(value)')
      print('type(name) = ' .. type(name))
      print('type(value) = ' .. type(value))
      print('type(maxRows) = ' .. type(maxRows))
      print('type(maxColumns) = ' .. type(maxColumns))
      print('type(formatString) = ' .. type(formatString))
      error('invalid call')
   end
   
   local function errorBadType(value)
      local msg = (string.format('value is type %s, not a Tensor', type(value)))
      usage(msg)
   end

   -- MAIN FUNCTION START HERE
   -- handle the first arg, which is optional so that f(b) --> f('', b)
   -- also type check arguments
   if type(name) == 'string' then
      if isTensor(value) then
         printNameValue(name, value, maxRows, maxColumns)
      else
         errorBadType(value)
      end
   elseif isTensor(name) then
      if type(formatString) == 'nil' then
         printNameValue('', name, value, maxRows, maxColumns) -- shift args over one position
      else
         usage()
      end
   else
      usage()
   end
end

local function printFunctionNameValue(f, name, value)
   print(string.format('%s: %s = %s', f, name, tostring(value)))
end

function pp.variable(variableName)
   assert(variableName ~= nil, 'missing variableName argument')
   local sf = StackFrame('caller')
   local functionName = sf:functionName()
   local value = tostring(sf:variableValue(variableName))
   printFunctionNameValue(ifelse(functionName == nil, '<unknown>', functionName), variableName, value)
end

function pp.variables(...)
   require 'printTableValue'
   local args = {...}
   local sf = StackFrame('caller')
   local functionName = sf:functionName()
   local bindings = sf.values
   if #args == 0 then
      -- print values of all bound variables
      for k, v in pairs(bindings) do
         printFunctionNameValue(functionName, k, v)
      end
   else
      -- print values of selected variables
      for i = 1, #args do
         local variableName = args[i]
         local variableValue = bindings[variableName]
         printFunctionNameValue(functionName, variableName, variableValue)
      end
   end
end
