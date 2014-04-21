-- readKnnInfoConsolidated_test.lua
-- unit test
-- test by using cachedComputation2, which has the side effect of creating a cache file
-- NOTE: creates the file readKnnInfoConsolidated_cache.serialized, which is huge, and
-- in Dropbox and takes 36 hours to upload. So run carefully.

require 'cachedComputation2'
require 'fileDelete'
require 'fileExists'
require 'ifelse'
require 'pp'
require 'readKnnInfoConsolidated'
require 'Timer'

local function test()
   local inputDir = '../data/v6/output/knninfo/impute-shards/'
   local inputFileBaseName = 'program_impute_knninfo_consolidate_shards_to_serialized_objects'
   local inputFileSuffix = '.serialized'
   local inputFileName = inputFileBaseName .. inputFileSuffix
   local inputPath = inputDir .. inputFileName

   -- delete any cache
   local pathToCache = '../data/v6/output/readKnnInfoConsolidated_cache.serialized'
   if fileExists(pathToCache) then
      fileDelete(pathToCache)
      print('deleted cache', pathToCache)
   end

   local config = {
      newSize = 256,
      --newSize = 128,
      implementation = 1,
      nShards = 1,  -- works for cache_implementation 1
      nShards = 10, -- works for cache_implementation 1  
      --nShards = 100, -- out of memory while writing
      implementation = 2,
      nShards = 1,   
      nShards = 10, 
      nShards = 100, -- works for write and read!
      --nShards = 1, -- to test
      -- with collect garbage every setting of consolidated table
   }
   pp.table('config', config)

   local arg = {
      newSize = config.newSize,
      nShards = config.nShards,
   }
   pp.table('arg', arg)

   -- read first time from disk, should take a long time
   local timer = Timer()
   local consolidated, info = cachedComputation2(pathToCache, readKnnInfoConsolidated, arg, config.implementation)
   local fromDiskCpu, fromDiskWallclock = timer:cpuWallclock()
   print(info.how, 'cpu', fromDiskCpu, 'wallclock', fromDiskWallclock)
   for k, v in pairs(info) do print('info key', k) end
   assert(info.how == 'from scratch')
   consolidated = nil
   print('memory used / 1e6 after writing', memoryUsed() / 1e6)

   local timer = Timer()
   local consolidated, info = cachedComputation2(pathToCache, readKnnInfoConsolidated, arg, config.implementation)
   local fromCacheCpu, fromCacheWallclock = timer:cpuWallclock()
   print(info.how, 'cpu', fromCacheCpu, 'wallclock', fromCacheWallclock)
   for k, v in pairs(info) do print('info key', k) end
   print('memory used / 1e6', memoryUsed() / 1e6)
   assert(info.how == 'used cache')
end

test()

print('ok readKnnInfoConsolidated')
