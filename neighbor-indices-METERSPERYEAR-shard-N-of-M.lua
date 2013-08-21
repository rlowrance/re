-- neighbor-indices-METERSPERYEAR-shard-N-of-M.lua
-- main program
-- COMMAND LINE PARAMETERS:
-- --metersPerYear K : meters in one year; K >= 0
-- --shard N         : shard to create, N in [0,M-1]); ex: --shard 23
-- --nShards M       : number of shards, M > 0; ex: --shards 100
-- FILES READ (in OUTPUT dir)
-- parcels-sfr-geocoded.csv
-- FILES WRITTEN (in OUTPUT dir)
-- neighbor-indices-METERSPERYEAR-shard-N-of-M.csv

require 'head'
require 'makeVp'
require 'memoryUsed'
require 'metersPerLatitudeDegree'
require 'metersPerLongitudeDegree'
require 'parseCommandLine'
require 'readParcelsLocations'
require 'startLogging'
require 'Timer'

-- determine 256 nearest neighbors using exact geometry
-- ARGS
-- queryIndex     : integer > 0, query in features
-- features       : NamedMatrix
-- metersPerYear  : kilometers in one year
-- nNeighbors     : number of neighbors, 256 (or some other value)
-- RETURNS 
-- indices        : 1D Tensor of indices of the nearest 256 neighbors to the query
local function nearestNeighbors(queryIndex, features, metersPerYear, nNeighbors)
   local vp, verboseLevel = makeVp(0, 'nearestNeighbors')
   local v = verboseLevel > 0
   vp(1,
      'queryIndex', queryIndex,
      'features', features,
      'metersPerYear', metersPerYear,
      'nNeighbors', nNeighbors)
   
   -- validate args
   assert(type(queryIndex) == 'number' and queryIndex > 0)
   assert(torch.typename(features) == 'NamedMatrix')
   assert(type(metersPerYear) == 'number' and 
          metersPerYear >= 0 and 
          math.floor(metersPerYear) == metersPerYear)
   assert(type(nNeighbors) == 'number' and nNeighbors > 0)
   local nObs = features.t:size(1)

   -- extract columns from features
   local latitudes = features.t:select(2, features:columnIndex('G LATITUDE'))
   local longitudes = features.t:select(2, features:columnIndex('G LONGITUDE'))
   local years = features.t:select(2, features:columnIndex('YEAR.BUILT'))
   if v then 
      vp(2, 
         'latitudes head', head(latitudes), 
         'longitudes head', head(longitudes), 
         'years head', head(years))
   end

   -- create Tensor of length nObs containing query values
   local queryLatitudes = torch.Tensor(nObs):fill(latitudes[queryIndex])
   local queryLongitudes = torch.Tensor(nObs):fill(longitudes[queryIndex])
   local queryYears = torch.Tensor(nObs):fill(years[queryIndex])

   -- determine average latitude from query point to all other points
   local avgLatitudes = torch.div(latitudes + queryLatitudes, 2)
   if v then vp(2, 'avgLatitudes head', head(avgLatitudes)) end

   -- determine differences in each coordinate
   local distances = torch.Tensor(nObs):zero()
   local deltaLongitudes =  torch.abs(queryLongitudes - longitudes)
   local deltaLatitudes =   torch.abs(queryLatitudes - latitudes)
   local deltaYears = torch.abs(queryYears - years)
   if v then
      vp(2,
         'deltaLongitudes head', head(deltaLongitudes),
         'deltaLatitudes head', head(deltaLatitudes),
         'deltaYears head', head(deltaYears))
   end

   -- convert coordinate differences to meters
   local meterLongitudes = torch.cmul(metersPerLongitudeDegree(avgLatitudes),
                                      deltaLongitudes)
   local meterLatitudes = torch.cmul(metersPerLatitudeDegree(avgLatitudes),
                                     deltaLatitudes)
   local meterYears = deltaYears * metersPerYear
   if v then 
      vp(2, 
         'meterLongitudes head', head(meterLongitudes),
         'meterLatitudes head', head(meterLatitudes),
         'meterYears head', head(meterYears))
   end

   -- determine distances in meters
   local dLongitudes = torch.cmul(meterLongitudes, meterLongitudes)
   local dLatitudes = torch.cmul(meterLatitudes, meterLatitudes)
   local dYears = torch.cmul(meterYears, meterYears)
   local distances = torch.sqrt(dLongitudes + dLatitudes + dYears)
   if v then vp(2, 'distances head', head(distances)) end

   -- determine indices of nNeighbors (256) nearest neighbors
   local sortedDistances, sortedIndices = torch.sort(distances)
   if v then
      vp(2, 
         'sortedDistances head', head(sortedDistances), 
         'sortedIndices head', head(sortedIndices))
   end
   
   return sortedIndices
end

-- main program
-- INPUT FILES:
-- parcels-sfr-geocoded.csv
--   Pparcel features with geocodes and APNs
-- OUTPUT FILES:
-- neighbor-indices-shared-N-of-M.csv
--   csv containing the nearest 256 APNs to every APN in the shard
-- ARGS
-- clArgs          : table of command line arguments, all ignored
-- metersPerYear   : number of kilometers assumed in one year
-- shard           : number of shard to produce
-- nShards         : number of shards all together
--                   shards are number 0, 1, 2, ..., nShards - 1
-- RETURNS nil
function main(clArgs)
   local vp = makeVp(1, 'main')
   vp(1, 'clArgs', clArgs)
   
   -- validate args
   assert(type(clArgs) == 'table')

   -- parse and validate command line
   local metersPerYear = tonumber(parseCommandLine(clArgs, 'value', '--metersPerYear'))
   local shard = tonumber(parseCommandLine(clArgs, 'value', '--shard'))
   local nShards = tonumber(parseCommandLine(clArgs, 'value', '--nShards'))
   vp(2, 'metersPerYear', metersPerYear, 'shard', shard, 'nShards', nShards)
 
   assert(type(metersPerYear) == 'number' and metersPerYear >= 0)
   assert(type(shard) == 'number' and 0 <= shard and shard <= nShards)
   assert(type(nShards) == 'number' and nShards > 0)

   -- setup file paths
   local dirOutput = '../data/v6/output/'
   local pathToInput = dirOutput .. 'parcels-sfr-geocoded.csv'
   local pathToOutputBase = 
      dirOutput .. 
      'neighbor-indices-' ..
      tostring(metersPerYear) .. '-' ..
      'shard-' .. tostring(shard) .. '-' ..
      'of-' .. tostring(nShards) 
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

   -- read all the data
   local readLimit = 1000
   local readLimit = -1
   if readLimit ~= -1 then
      print('TESTING: DISCARD OUTPUT')
   end
   local apnsNm, featuresNm = readParcelsLocations(pathToInput, readLimit)
   local apns = apnsNm.t:select(2,1)  -- select first column
   --vp(2, 'apns', apns)
   vp(2, 'apnsNm', apnsNm, 'featuresNm', featuresNm)


   if false then
      -- run timing tests: how much slower is the computation with exact geometry
      -- compared to using approximate geometry
      local queryIndex = 1
      local nNeighbors = 256
      local timerExact = Timer()
      local neighborsExact = 
         nearestNeighborsExact(queryIndex, apns, features, metersPerYear, nNeighbors)
      local cpuExact = timerExact:cpu()
      local timerApprox = Timer()
      local neighborsApprox = 
         nearestNeighborsApprox(queryIndex, apns, features, metersPerYear, nNeighbors)
      local cpuApprox = timerApprox:cpu()
      vp(0, 'cpuExact', cpuExact, 'cpuAppox', cpuAppox)
      assertEq(neighborsExact, neighborsApprox, 0)  -- may not be the same
      stop()
   end

   -- open csv 
   local csv, err = io.open(pathToOutput, 'w')
   if csv == nil then
      error(err)
   end

   -- write the header to the csv file
   local nNeighbors = 256
   assert(readLimit == -1 or nNeighbors <= readLimit + 1)
   local s = 'queryApn'
   for i = 1, nNeighbors do
      s = s .. ',' .. 'nearest-' .. tostring(i)
   end
   csv:write(s .. '\n')
   
   -- create the shard containing indicesindi of 256 nearest neighbors
   local timer = Timer()
   local nQueriesProcessed = 0
   local nFeatures = featuresNm.t:size(1)
   local indices
   for queryIndex = 1, nFeatures do
      if queryIndex % nShards == shard then
         nQueriesProcessed = nQueriesProcessed + 1
         indices = nearestNeighbors(queryIndex, 
                                    featuresNm, 
                                    metersPerYear, 
                                    nNeighbors + 1)

         -- maybe report progress
         local frequencyReport = 1000
         local frequencyGC = 10
         if nQueriesProcessed % frequencyReport == 1 then
            vp(0, 
               string.format('metersPerYear %d shard %d of %d ' ..
                             'queryIndex %d of %d avg cpu sec %f avg wallclock sec %f',
                              metersPerYear,
                              shard,
                              nShards,
                              queryIndex,
                              nFeatures,
                              timer:cpu() / nQueriesProcessed,
                              timer:wallclock() / nQueriesProcessed))
         end

         -- occasionally collect garbarge
         if nQueriesProcessed % frequencyGC == 0 then
            local used = memoryUsed()  -- collect garbage and determine bytes used
            vp(2, 'memory used after gc', used)
         end

         -- write the record
         vp(2, 'queryIndex', queryIndex, 'apns[queryIndex]', apns[queryIndex])
         csv:write(string.format('%d,', apns[queryIndex]))
         for j = 1, nNeighbors do
            if j ~= 1 then csv:write(',') end
            -- don't write the first index, as it is the query point
            csv:write(string.format('%d', apns[indices[j + 1]]))
         end
         csv:write('\n')

         -- debugging
         --if nQueriesProcessed == 10 then break end
      end
   end

   -- close the csv file
   csv:close()

   vp(0, 'number of records written', nQueriesProcessed)
end

main(arg)   
         
   