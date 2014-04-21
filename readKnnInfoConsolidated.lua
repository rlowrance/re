-- readKnnInfoConsolidated.lua

require 'knn'
require 'memoryUsed'
require 'pp'
require 'torch'

-- read file program_impute_knninfo_consolidate_shards_to_serialized_objects[_debug].serializedObjects
-- conform to API of function cachedComputation2()
-- ARGS:
-- arg   : nil or table with these fields
--         .newSize : integer > 0, each knnInfo is shortened to this size (<= 1024)
--         .nShards : integer > 0, default 100; number of shards to read (for testing)
-- RETURNS
-- result : number, version number, if arg == nil
--          table s.t table[queryIndex] = knnInfo
-- NOTES: takes a long time, consider wrapping your call in cachedComputation2
function readKnnInfoConsolidated(arg)
   local debug = true
   if arg == nil then
      return 6  -- return version number
   end

   if debug then pp.table('arg', arg) end
   assert(type(arg) == 'table')

   local function isQueryIndex(value)
      return type(value) == 'number' and value >= 1
   end

   local function consolidateShard(shardNumber, consolidated)
      local inPathBase = '../data/v6/output/knninfo/impute-shards/program_impute_knninfo_make_shard_'
      local inPath = inPathBase .. tostring(shardNumber) .. '.serialized'
      print('inPath', inPath)
      if fileExists(inPath) then
         local shard = torch.load(inPath)
         local count = 0
         for queryIndex, knnInfo in pairs(shard) do
            count = count + 1
            if isQueryIndex(queryIndex) then
               if knn.isKnnInfo(knnInfo) then
                  consolidated[queryIndex] = knnInfo
               else
                  print('bad knnInfo', shardNumber, count, tostring(knnInfo))
               end
            else
               print('bad queryIndex', shardNumber, count, tostring(queryIndex))
            end
         end
         shard = nil  -- try to assist the garbage collector
      else
         error(string.format('did not find shard %d', shardNumber))
      end
   end

   local consolidated = {}
   for shardNumber = 0, arg.nShards - 1 do
      consolidateShard(shardNumber, consolidated)
      print('readKnnInfoConsolidate', 'shardNumber', shardNumber, 'memoryUsed / 1e6', memoryUsed() / 1e6)
   end

   return consolidated
end
