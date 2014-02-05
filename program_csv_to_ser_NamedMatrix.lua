-- program_csv_to_ser_NamedMatrix.lua
-- main program to convert a csv file to a serialized named matrix
-- COMMAND LINE ARGS
-- --input file-name
-- --output file-name
-- --factors name, name, ...
--   names of factor columns, if any
--   all other columns are considered number columns
-- INPUT FILES:
-- OUTPUT FILES:

require 'equalObjectValues'
require 'isnan'
require 'NamedMatrix'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'splitString'
require 'torch'

-- return table containing value from parsed command line
local function parseCommandLine(arg)
   local clArgs = {}
   local index = 1
   while index <= #arg do
      local keyword = arg[index]
      index = index + 1
      if keyword == '--input' then
         clArgs.input = arg[index]
         index = index + 1
      elseif keyword == '--output' then
         clArgs.output = arg[index]
         index = index + 1
      elseif keyword == '--factors' then
         local factors = {}
         repeat
            table.insert(factors, arg[index])
            index = index + 1
         until index > #arg or string.sub(arg[index], 1, 2) == '--'
         clArgs.factors = factors
      else
         error('? ' .. keyword)
      end
   end

   assert(clArgs.input ~= nil, 'missing --input argument')
   assert(clArgs.output ~= nil, 'missing --output argument')
   assert(clArgs.factors ~= nil, 'missing --factors argument')
   return clArgs
end

-- return sequence of column headings from the input file
local function getAllColumns(inputPath)
   local fileHandle, errorMessage = io.open(inputPath, 'r')
   if fileHandle == nil then
      error(errorMessage)
   end
   header = fileHandle:read('*l')  -- read next line, skipping endof line
   allColumns = splitString(header, ',')
   return allColumns
end

-- return true if the sequence contains the specified element
local function contains(sequence, element)
   for _, item in ipairs(sequence) do
      if item == element then
         return true
      end
   end
   return false
end

-- return sequence containing elements in A that are not in B
local function subtract(sequenceA, sequenceB)
   local result = {}
   for _, element in ipairs(sequenceA) do
      if not contains(sequenceB, element) then
         table.insert(result, element)
      end
   end
   return result
end

-- print cpu and wall clock times
local function printTimes(msg, cpu, wallclock)
   print(msg .. ' cpu seconds = ' .. cpu .. '  wall clock seconds = ' .. wallclock)
end

-- return whether-equal and explanation string
local function equalNamedMatrix(a, b)
   local equal, whyNot = equalObjectValues(a.names, b.names)
   if not equal then 
      stop()
      return equal, 'names not equal; ' .. whyNot
   end
   
   local equal, whyNot = equalObjectValues(a.levels, b.levels)
   if not equal then
      stop()
      return equal, 'levels not equal; ' .. whyNot
   end

   local equal, whyNot = equalObjectValues(a.t, b.t)
   if not equal then
      print(whyNot)
      stop()
      return equal, 'tensors not equal: ' .. whyNot
   end

   return true
end

-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------


local clArgs = parseCommandLine(arg)
local allColumns = getAllColumns(clArgs.input)
local factorColumns = clArgs.factors
local numberColumns = subtract(allColumns, factorColumns)
 
-- read input data as a csv file
print('reading csv file ' .. clArgs.input)
local csvTimer = Timer()
local csv = NamedMatrix.readCsv{
   file=clArgs.input,
   sep=',',
   nanString='',
   nRows=-1,
   numberColumns=numberColumns,
   factorColumns=factorColumns,
   skip=0}
local csvCpu, csvWallclock = csvTimer:cpuWallclock()
printTimes('csv', csvCpu, csvWallclock)
assert(csv.t[1][3] == 913062344, csv.t[1])

-- write serialized version for the data in the csv file
print('writing serialized file ' .. clArgs.output)
local formatSerialized = 'binary'
--local formatSerialized = 'ascii'  NOTE: ASCII doesn't work, because of bug in torch.save
torch.save(clArgs.output, csv, formatSerialized)

-- as a test, read input data as a serialized file
print('reading serialized file ' .. clArgs.output)
local serializedTimer = Timer()
local serialized = torch.load(clArgs.output, formatSerialized)
local serializedCpu, serializedWallclock = serializedTimer:cpuWallclock()
printTimes('serialized', serializedCpu, serializedWallclock)

-- make sure the conversion from csv to serialized didn't loose info
print('comparing values in csv and serialized files')
local equal, whyNot = equalNamedMatrix(csv, serialized)
assert(equal, whyNot)


assert(formatSerialized == 'binary')  -- avoid but in torch.save()

print('done')

