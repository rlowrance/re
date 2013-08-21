-- neighbor-indices-METERSPERYEAR.lua
-- main program to consolidate shared of neighbor indices into one big file
-- COMMAND LINE INPUTS
-- --[all|some]      default all
--                   whether all shards are required for success
-- --nShards N       number of shards
-- --metersPerYear M meters per year
-- INPUT FILES
-- neighbor-indices-METERSPERYEAR-shard-<shard>-of-<nShards>.csv
--   one or more files containing shards
-- OUTPUT FILES
-- neighbor-indices-METERSPERYEAR.csv
-- neighbor-indices-METERSPERYEAR.log

require 'makeVp'
require 'parseCommandLine'
require 'startLogging'

local function copyFile(firstFile, inFile, outFile)
   if firstFile then
      local header = inFile:read('*L')  -- keep \n
      outFile:write(header)
   end

   local data = inFile:read('*L')
   local nDataRecords = 0
   while data do
      outFile:write(data)
      nDataRecords = nDataRecords + 1
      data = inFile:read('*L')
   end

   return nDataRecords
end

function main(clArgs)
   local vp = makeVp(1, 'main')
   vp(1, 'clArgs', clArgs)
   
   -- validate args
   assert(type(clArgs) == 'table')

   -- parse and validate command line
   local metersPerYear = 
      tonumber(parseCommandLine(clArgs, 'value', '--metersPerYear'))
   local nShards = tonumber(parseCommandLine(clArgs, 'value', '--nShards'))
   local all = parseCommandLine(clArgs, 'present', '--all')
   local some = parseCommandLine(clArgs, 'present', '--some')

   assert(type(metersPerYear) == 'number' and metersPerYear >= 0)
   assert(type(nShards) == 'number' and nShards > 0)
   assert(all or some)

   -- setup file paths
   local dirOutput = '../data/v6/output/'
   --local pathToInput = dirOutput .. 'parcels-sfr-geocoded.csv'
   local pathToOutputBase = 
      dirOutput .. 
      'neighbor-indices-' ..
      tostring(metersPerYear)
   local pathToOutput = pathToOutputBase .. '.csv'
   local pathToLogFile = pathToOutputBase .. '.log'

   torch.manualSeed(20110513)
   
   local clArgs = arg
   startLogging(pathToLogFile, clArgs)
   -- now print writes to log file
   vp(0, 'paths to files')
   vp(1, 
      'pathToInput', pathToInput,
      'pathToOutput', pathToOutput,
      'pathToLogFile', pathToLogFile)

   -- how much of each data file to read
   local readLimit = 1000
   local readLimit = -1
   if readLimit ~= -1 then
      print('TESTING: DISCARD OUTPUT')
   end

   -- copy input file to output file, adding exactly 1 header
   local outFile, err = io.open(pathToOutput, 'w')
   if outFile == nil then
      error('unable to open output file ' .. tostring(err))
   end
   local firstFile = true

   local totalDataRecords = 0
   for shard = 0, nShards - 1 do
      local pathToInput = 
         dirOutput .. 
         'neighbor-indices-' .. tostring(metersPerYear) ..
         '-shard-' .. tostring(shard) ..
         '-of-' .. tostring(nShards) ..
         '.csv'
      vp(2, 'pathToInput', pathToInput)
      local inFile, err = io.open(pathToInput)
      if inFile == nil then
         -- assume file is missing
         if some then
            vp(0, 'did not find file ' .. pathToInput)
            
         else
            error('unable to input: ' .. tostring(err))
         end
      end

      if inFile ~= nil then
         local nDataRecords = copyFile(firstFile, inFile, outFile)
         vp(0, string.format('read %d data records from %s',
                             nDataRecords, pathToInput))
         local totalDataRecords = totalDataRecords + nDataRecords
         firstFile = false
         io.close(inFile)
      end
      if shard == 10 then stop() end
   end

   io.close(outFile)
   print(string.format('wrote %d data records to %s',
                       totalDataRecords, pathToOutput))
end
   
main(arg)   
         
   