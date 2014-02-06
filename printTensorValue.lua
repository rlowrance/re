-- printTensorValua.lua
-- print value of a Tensor

require 'isTensor'
require 'makeVp'

-- ARGS
-- name       : optional string, name of variable holding a table value
-- value      : table
-- maxRows    : optional integer, default value:size(1)
-- maxColumns : optional integer, default value:size(2)
-- formatString : option string used to format each number, default is '%.4g'
function printTensorValue(name, value, maxRows, maxColumns, formatString)
   local vp = makeVp(1, 'printTensorValue')
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
      local vp = makeVp(2, 'printNameValue')
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
