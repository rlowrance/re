-- readKnnInfoConsolidated_timing.lua
-- timing test
-- compare reading times with and without using cachedComputation2

-- output from system Carmen: without the cache is much faster!
-- config           without cache    with cache
-- cpu sec          371              1269
-- wallclock sec    389              1273

-- CONCLUSION: better to run without the cache for implementation 2

require 'cachedComputation2'
require 'fileDelete'
require 'fileExists'
require 'ifelse'
require 'pp'
require 'readKnnInfoConsolidated'
require 'Timer'

local function makeArg()
   return {
      newSize = 256,
      nShards = 100,
   }
end

local function runNoCache()
   local consolidate = readKnnInfoConsolidated(makeArg())
end

local function runCache()
   local pathToCache = '../data/v6/output/readKnnInfoConsolidated_cache.serialized'
   local implementation = 2
   local consolidated, info = cachedComputation2(pathToCache, readKnnInfoConsolidated, makeArg(), implementation)
   assert(info.how == 'used cache', tostring(info.how))
end

-- time reading without the cache
collectgarbage()
local timer = Timer()
runNoCache()
local nocacheCpu, nocacheWallclock = timer:cpuWallclock()
print('no cache', nocacheCpu, 'wallclock', nocacheWallclock)

-- time reading with the cache
collectgarbage()
local timer = Timer()
runCache()
local cacheCpu, cacheWallclock = timer:cpuWallclock()
print('with cache', cacheCpu, 'wallclock', cacheWallclock)
