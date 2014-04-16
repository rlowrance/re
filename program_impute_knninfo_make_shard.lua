-- program_impute_knninfo_make_shard.lua
-- COMMAND LINE ARGS
-- --shard N
-- INPUT FILES
-- ../data/v6/output/parcels-sft-geocoded.csv
-- INPUT and OUTPUT FILES
-- ../data/v6/output/program_impute_knninfo_make_share_N.serialized
--
-- NOTES
-- - there are 100 shards
-- - program_impute_knninfo_combine_shards.lua combines the 100 shared into one file

require 'CommandLine'
require 'distanceSpace2'
require 'distanceTime2'
require 'knn'
require 'memoryUsed'
require 'pp'
require 'readParcelsForImputation'
require 'readViaSerializedFile'
require 'tensor'
require 'time'
require 'Timer'
 
local function parseCommandLine(args)
   assert(#args > 0, 'command line args: --shard N [--dataDir path]')
   local cl = CommandLine(args)
   return {
      me = 'program_impute_knninfo_make_shard',  -- name of executable
      shard = tonumber(cl:required('--shard')),
      dataDir = cl:defaultable('--dataDir', '../data/v6/output/'),
   }
end

-- convert tensors to torch.FloatTensor
local function toShorterTensors(knnInfo)
   return {
      space = {
         dSpace2 = knnInfo.space.dSpace2:type('torch.FloatTensor'),
         dTime2 = knnInfo.space.dTime2:type('torch.FloatTensor'),
         index = knnInfo.space.index:type('torch.IntTensor'),
      },
      time = {
         dSpace2 = knnInfo.time.dSpace2:type('torch.FloatTensor'),
         dTime2 = knnInfo.time.dTime2:type('torch.FloatTensor'),
         index = knnInfo.time.index:type('torch.IntTensor'),
      },
   }
end

-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local timer = Timer()
local cl = parseCommandLine(arg)
pp.table('cl', cl)

local outputFileName = cl.me .. '_' .. tostring(cl.shard) .. '.serialized'

local config = {
   nShards = 1,  -- for now
   nShards = 100,
   reportFrequency = 1, -- for now
   --reportFreuency = 100,
   checkpointFrequency = 1,
   checkpointFrequency = 10,
   --checkpointFrequency = 100,  LEADS TO USING TOO MUCH MEMORY
   --checkpointFrequency = 1000,
   cgFrequency = 10,   -- collect garbage
   cgFrequency = 5,   -- collect garbage
   readlimit = 10,
   readlimit = -1,
   inputFilePath = cl.dataDir .. 'parcels-sfr-geocoded.csv',
   outputFilePath = cl.dataDir .. outputFileName,
   checkpointFilePath = '/tmp/' .. outputFileName,
   maxK = 5,
   maxK = 1024,
}

pp.table('config', config)

-- check command line args
assert(cl.shard >= 0)
assert(cl.shard < config.nShards)


if config.nshards == 1 or config.readlimit ~= -1 then
   print('TESTING: RERUN')
end


local usedCache, table, msg = readViaSerializedFile(config.inputFilePath, 
                                                    readParcelsForImputation, 
                                                    {readlimit = config.readlimit})
print('usedCache', usedCache)
print('msg', msg)
local features = table.nm
print('features.t:size()', features.t:size())

local nSamples = features.t:size(1)
assert(nSamples < 2e9)  -- make sure sample indices fit into 32 bit integer

local columnIndexLatitude = features:columnIndex('G LATITUDE')
local columnIndexLongitude = features:columnIndex('G LONGITUDE')
local columnIndexYear = features:columnIndex('YEAR.BUILT')

local latitudes = tensor.viewColumn(features.t, columnIndexLatitude)
local longitudes = tensor.viewColumn(features.t, columnIndexLongitude)
local years = tensor.viewColumn(features.t, columnIndexYear)

local function dSpace2(features, queryIndex)
   return distanceSpace2(latitudes, 
                         longitudes, 
                         features.t[queryIndex][columnIndexLatitude],
                         features.t[queryIndex][columnIndexLongitude])
end

local function dTime2(features, queryIndex)
   return distanceTime2(years, 
                        features.t[queryIndex][columnIndexYear])
end

local knnInfos = {}
local nComputed = 0
for sampleIndex = cl.shard, nSamples, config.nShards do

   local cpu, wallclock
   cpu, wallclock, knnInfo = time('both', knn.knnInfo, sampleIndex, features, config.maxK, dSpace2, dTime2)
   knnInfos[sampleIndex] = toShorterTensors(knnInfo)

   nComputed = nComputed + 1
   if nComputed == 1 or nComputed % config.reportFrequency == 0 then
      print(string.format('shard %d sampleIndex %d nComputed %d of %d: cpu %f wallclock %f'
                         ,cl.shard
                         ,sampleIndex
                         ,nComputed
                         ,nSamples / config.nShards
                         ,cpu
                         ,wallclock
                         )
      )
   end

   if nComputed == 1 or nComputed % config.cgFrequency == 0 then
      -- collect garbage
      local memoryUsed = memoryUsed()
      print(string.format(' using %d bytes after garbage collection', memoryUsed))
   end
   if false and sampleIndex > 100 then break end  -- while debugging
end

print('writing knnInfos')
torch.save(config.outputFilePath, knnInfos)
print(string.format('wrote %d knnInfo packets to file %s', nComputed, config.outputFile))

local cpu, wallclock = timer:cpuWallclock()
print('execution cpu', cpu)
print('execution wallclock seconds', wallclock)
print('execution wallclock hours', wallclock / 60 / 60)
