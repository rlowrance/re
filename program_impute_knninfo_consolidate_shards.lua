-- program_impute_knninfo_consolidate_shards.lua
-- COMMAND LINE ARGS
-- [--dataDir path/to/directory]
-- INPUT FILES
-- ../data/v6/output/program_impute_knninfo_make_share_N.serialized
--   for N - 0 up to 99 
-- ../data/v6/output/parcels-sft-geocoded.csv
-- OUTPUT FILES
-- ../data/v6/output/program_impute_knninfo_consolidate_shards.serialized
--
-- NOTES
-- - there are 100 shards

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
 
local function parseCommandLine(args)
   assert(#args >= 0, 'command line args: [--dataDir path]')
   pp.table('args', args)
   local cl = CommandLine(args)
   return {
      me = 'program_impute_knninfo_make_shard',  -- name of executable
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

-- merge shard into all, verifying no duplicates
-- return number of samples indices in the shard
local function consolidate(shard, all)
   local debug = false
   local count = 0
   for sampleIndex, knnInfo in pairs(shard) do
      if debug then
         print('sampleIndex', sampleIndex)
         pp.table('knnInfo', knnInfo)
      end

      count = count + 1
      assert(all[sampleIndex] == nil,
             string.format('sampleIndex %d already processed', sampleIndex))
      all[sampleIndex] = knnInfo
   end
   return count
end

-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local cl = parseCommandLine(arg)
pp.table('cl', cl)

local config = {
   nShards = 1,  -- for now
   nShards = 100,
   gcFrequency = 1,
   gcFrequency = 10,
   baseInputFileName = 'program_impute_knninfo_make_shard_',
   outputFilePath = cl.dataDir .. cl.me .. '.serialized',
}

pp.table('config', config)

local consolidated = {}
local someMissing = false
for shardNumber = 0, config.nShards do
   local inPath = cl.dataDir .. config.baseInputFileName .. tostring(shardNumber) .. '.serialized'
   if fileExists(inPath) then
      local shard = torch.load(inPath)
      local count = consolidate(shard, consolidated)
      print(string.format('saved %d sample indices in shard %d', count, shardNumber))
   else
      print(string.format('did not find shard %d', shardNumber))
      someMissing = true
   end
   if shardNumber == 1 or (shardNumber % config.gcFrequency == 0) then
      local memoryUsed = memoryUsed()  -- also collect garbarge
      print(string.format('using %d bytes after garbage collection', memoryUsed))
   end
end

torch.save(config.outputFilePath, consolidated)
print(string.format('wrote consolidated knnInfo table to %s', config.outputFilePath))

if someMissing then
   print('SOME SHARDS WERE MISSING')
end
