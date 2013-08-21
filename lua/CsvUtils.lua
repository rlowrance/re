-- CsvUtils.lua
-- various methods for reading Csv files

-- API overview
if false then
   cu = CvsUtils()

   values, header = cu:readNumbers(inFilepath,
                                   hasHeader,
                                   returnKind, -- 'array' or '2D Tensor'
                                   inputLimit) -- if > 0

   values, header = cu:read1Number(inFilepath,
                                   hasHeader,
                                   returnKind, -- 'array' or '1D Tensor'
                                   inputLimit) -- if > 0
end -- API overview


local CsvUtils = torch.class('CsvUtils')

--------------------------------------------------------------------------------
-- __init
--------------------------------------------------------------------------------

function CsvUtils:__init()
end

--------------------------------------------------------------------------------
-- readNumbers
--------------------------------------------------------------------------------

-- return array of arrays of values or 2D tensor and the header
-- handle only simple CSV comma-separated files (no quotes)
-- ARGS:
-- inFilePath   string, path to csv file
-- hasHeader    boolean, true iff file has a header
-- returnKind   optional string
--               if 'array' or nil, return array of arrays
--               if '2D Tensor', return 2D Tensor, one row for each record
-- inputLimit   option number >= 0
--              if not 0, only inputLimit data records are read
--              intended for testing
-- RETURNS:
-- values from file, either array of arrays or array of Tensors
-- header from file, a string
function CsvUtils:readNumbers(inFilePath, hasHeader, returnKind, inputLimit)
   local trace = false
   assert(inFilePath)
   assert(hasHeader == true or hasHeader == false)
   assert(returnKind)
   assert(returnKind == nil or 
          returnKind == 'array' or 
          returnKind == '2D Tensor', 'bad returnKind:' .. tostring(returnKind))

   -- inputLimit of 0 or nil means to read all the input records
   local inputLimit = self:_setInputLimit(inputLimit)

   if trace then print('\nin CsvUtils.readNumbers') end

   local file = io.open(inFilePath)
   assert(file, 'bad inFilePath: ' .. inFilePath)
   local header
   if hasHeader then 
      header = file:read()
   end
   local values = {}
   local count = 0
   for line in file:lines('*l') do
      if trace then print('line', line) end
      count = count + 1
      if inputLimit > 0 and count > inputLimit then break end
      local array = {}
      local numFields = 0
      for w in string.gmatch(line, '[^,]+') do
         if trace then print('w', w) end
         local num = tonumber(w)
         if trace then print('num', num) end
         if num then
            array[#array + 1] = num
            numFields = numFields + 1
         else
            print(' count', count)
            print(' line', line)
            print(' field', w)
            print(' num', num)
            error('field not convertable to a double value')
            os.exit(1) -- exit with failure
         end
      end
      if numbFields ~= 0 and numFields ~= #array then
         print('wrong number of fields')
         print(' line', line)
         print(' numberFields', numberFields)
         os.exit(1) -- exit with failure
      end
      if trace then print('array', array) end
      values[#values + 1] = array
   end

   if trace then print('values', values) end
   if trace then print('header', header) end
   
   if returnKind == '2D Tensor' then
      values = torch.Tensor(values)
   end

   return values, header
end -- readNumbers

--------------------------------------------------------------------------------
-- read1Number
--------------------------------------------------------------------------------

-- return array of numbers and header from a 1-column CSV file
-- ARGS:
-- inFilePath   string, path to csv file
-- hasHeader    boolean, true iff file has a header
-- returnKind   optional string
--               if 'array' or nil, return array of arrays
--               if '1D Tensor', return 1D Tensor, one row for each record
-- inputLimit   option number >= 0
--              if not 0, only inputLimit data records are read
--              intended for testing
-- RETURNS:
-- values from file, either array of arrays or array of Tensors
-- header from file, a string
function CsvUtils:read1Number(inFilePath, hasHeader, returnKind, inputLimit)
   trace = false
   assert(inFilePath)
   assert(hasHeader == true or hasHeader == false)
   assert(returnKind)
   assert(returnKind == 'array' or returnKind == '1D Tensor')
   
   local inputLimit = CsvUtils:_setInputLimit(inputLimit)

   local file = io.open(inFilePath, 'r')
   assert(file, 'bad InFilePath: ' .. inFilePath)

   local header
   if hasHeader then
      header = file:read()
   end

   local values = {}
   local count = 0
   for line in file:lines('*l') do
      count = count + 1
      if trace then
         print(count, 'line', line)
      end
      if inputLimit > 0 and count > inputLimit then break end
      local valueString = string.match(line,'^.*$')
      assert(valueString, 'input line not parsed: ' .. line)
      local value = tonumber(valueString)
      assert(value, 'not converted to number:' .. valueString)
      values[#values+1] = value
   end
   file:close()

   if returnKind == '1D Tensor' then
      values = torch.Tensor(values)
   end

   return values, header
end -- read1Number

--------------------------------------------------------------------------------
-- read1String
--------------------------------------------------------------------------------

-- return array of strings and header from a 1-column CSV file
function CsvUtils:read1String(inFilePath, inputLimit)
   local inputLimit = CsvUtils._setInputLimit(inputLimit)
   local file = io.open(inFilePath, 'r')
   assert(file, 'bad InFilePath: ' .. inFilePath)
   local header = file:read() -- ignore the header
   local values = {}
   local count = 0
   for line in file:lines('*l') do
      count = count + 1
      if inputLimit > 0 and count > inputLimit then break end
      local valueString = string.match(line,'^.*$')
      assert(valueString, 'not parsed: ' .. line)
      values[#values+1] = valueString
   end
   file:close()
   return values, header
end

--------------------------------------------------------------------------------
-- read3Strings
--------------------------------------------------------------------------------

-- return 3 arrays of strings and header from a 3-column CSV file
function CsvUtils:read3Strings(inFilePath, pattern, inputLimit)
   local inputLimit = CsvUtils._setInputLimit(inputLimit)
   local file = io.open(inFilePath, 'r')
   assert(file, 'bad InFilePath: ' .. inFilePath)
   local header = file:read('*l')
   local as = {}
   local bs = {}
   local cs = {}
   local count = 0
   for line in file:lines('*l') do
      count = count + 1
      if inputLimit > 0 and count > inputLimit then break end
      local a, b, c = string.match(line, pattern)
      -- check that all values were parsed
      assert(a, 'not parsed: ' .. line)
      assert(b, 'not parsed: ' .. line)
      assert(c, 'not parsed: ' .. line)
      -- create output arrays
      as[#as+1] = a
      bs[#bs+1] = b
      cs[#cs+1] = c
   end
   file:close()
   return as, bs, cs, header
end


--------------------------------------------------------------------------------
-- _setInputLimit
--------------------------------------------------------------------------------

-- type and value check inputLimit and provide a default value of zero
-- private
function CsvUtils:_setInputLimit(inputLimit)
   if inputLimit == nil then
      return 0
   else
      assert(inputLimit >= 0)
      assert(type(inputLimit) == 'number')
      return inputLimit
   end
end
