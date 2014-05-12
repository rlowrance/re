-- readKnnInfoConsolidated_test.lua
-- unit test
-- test by using cachedComputation2, which has the side effect of creating a cache file
-- NOTE: creates the file readKnnInfoConsolidated_cache.serialized, which is huge, and
-- in Dropbox and takes 36 hours to upload. So run carefully.

require 'cachedComputation2'
require 'fileDelete'
require 'fileExists'
require 'ifelse'
require 'knn'
require 'object'
require 'pp'
require 'readKnnInfoConsolidated'
require 'tableCount'
require 'Timer'

local function test(version)
   local debug = true
   local debug = function(a, b) if debug then print(a,b) end end
   local arg = {
      newSize = 256,
      nShards = 100, -- read them all
      --nShards = 2,
      version = version,
   }
   local versionNumber = readKnnInfoConsolidated()
   assert(type(versionNumber) == 'number')

   local consolidated = readKnnInfoConsolidated(arg)
   if version == 1 then
      for queryIndex, knnInfo in pairs(consolidated) do
         if debug then print('queryIndex', queryIndex) pp.knnInfo('knnInfo', knnInfo) end
         assert(type(queryIndex) == 'number')
         assert(knn.isKnnInfo(knnInfo))
         break
      end
   elseif version == 2 then
      print('type(consolidate)', type(consolidated))
      pp.table('consolidated', consolidated)
      assert(type(consolidated) == 'table')
      debug('calculated bytes in consolidated', object.nBytes(consolidated))
      if debug then pp.table('consolidated', consolidated) end
   end

end

local function testViaCachedComputation2()
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

local timer = Timer()
test(2)
local cpu, wallclock = timer:cpuWallclock()
if debug then 
   print('test timing') 
   print('cpu', cpu) 
   print('wallclock', wallclock) 
end

--testViaCachedComputation2()

print('ok readKnnInfoConsolidated')
