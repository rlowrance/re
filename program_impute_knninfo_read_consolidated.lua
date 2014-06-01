-- program_impute_knninfo_read_consolidated.lua
-- COMMAND LINE ARGS
-- [--dataDir path/to/directory]
-- INPUT FILES
-- ../data/v6/output/program_impute_knninfo_consolidated_shards_part_A.serialized
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
require 'ifelse'
require 'knn'
require 'memoryUsed'
require 'pp'
require 'readParcelsForImputation'
require 'readViaSerializedFile'
require 'tensor'
require 'tableMapValues'
require 'time'
 
local function parseCommandLine(args)--{{{
   assert(#args >= 0, 'command line args: [--dataDir path]')
   pp.table('args', args)
   local cl = CommandLine(args)
   return {
      me = 'program_impute_knninfo_read_consolidated',  -- name of executable
      dataDir = cl:defaultable('--dataDir', '../data/v6/output/'),
   }
end--}}}

-- merge shard into all, verifying no duplicates--{{{
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
end--}}}


-- shorten the sequence of tensors--{{{
function knn.trim(knnInfo, newSize)
   -- keep just the first newSize elements
   local function keepPrefix(v)
      local typename = torch.typename(v)
      assert(typename == 'torch.FloatTensor' or typename == 'torch.IntTensor')
      local constructor = ifelse(typename == 'torch.FloatTensor', torch.FloatTensor, torch.IntTensor)
      local result = constructor(v:storage(), 1, newSize, 1):clone()
      return result
   end
   
   return tableMapValues(knnInfo, keepPrefix)
end--}}}


-- read all the knnInfos, retaining a prefix of each Tensor
function knn.readConsolidated(outputDir, newSize)--{{{
   local debug = true
   local pathToInputBase = outputDir .. 'program_impute_knninfo_consolidate_shards_part_'
   local consolidated = {}

   local function read(part)
      if debug then
         print('knn.readConsolidated::read::part', part)
      end
      local knnInfos = torch.load(pathToInputBase .. part .. '.serialized')
      local trimmed = knn.trim(knnInfos, newSize)
      for k, v in pairs(trimmed) do
         assert(type(k) == 'number')
         consolidated[k] = knn.trim(v, newSize)
      end
      knnInfos = nil  -- try to help the garbage collector
   end

   read('a')
   local used = memoryUsed()
   if debug then 
      print('memory used X 10^6', used / 1e6)
   end

   read('b')
   local used = memoryUsed()
   if debug then 
      print('memory used X 10^6', used / 1e6)
   end

   read('c')
   local used = memoryUsed()
   if debug then 
      print('memory used X 10^6', used / 1e6)
   end

   return consolidated
      
end--}}}


-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local cl = parseCommandLine(arg)
pp.table('cl', cl)

local config = {
   trimmedSize = 512, -- not enough memory
   trimmedSize = 256, -- not enough memory
   trimmedSize = 1, -- not enough memory !
   trimmedSize = 1024,
   trimmedSize = 128,
   trimmedSize = 64,
   trimmedSize = 32,
   trimmedSize = 1,
   debug = true,
}

pp.table('config', config)

local consolidated = knn.readConsolidated(cl.dataDir, config.trimmedSize)
collect()
print('trimmed size =', config.trimmedSize)
print('done')
