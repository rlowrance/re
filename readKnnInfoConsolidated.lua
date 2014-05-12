-- readKnnInfoConsolidated.lua

require 'knn'
require 'memoryUsed'
require 'pp'
require 'torch'

-- read 100 shards of KnnInfo and return consolidation table
-- conform to API of function cachedComputation2()
-- ARGS:
-- arg   : nil or table with these fields
--         .newSize : integer > 0, each knnInfo is shortened to this size (<= 1024)
--         .nShards : integer > 0, default 100; number of shards to read (for testing)
--         .version : integer in {1, 2}
-- RETURNS
-- result : number, version number, if arg == nil
--          table s.t table[queryIndex] = knnInfo
-- NOTES: takes a long time, consider wrapping your call in cachedComputation2
function readKnnInfoConsolidated(arg)
   local debug = true
   local function dp(a,b) if debug then print(a,b) end end

   if arg == nil then
      return 6  -- return version number
   end

   if debug then pp.table('arg', arg) end
   assert(type(arg) == 'table')

   local function isQueryIndex(value)
      return type(value) == 'number' and value >= 1
   end

   local function readShard(shardNumber)
      local inPathBase = '../data/v6/output/knninfo/impute-shards/program_impute_knninfo_make_shard_'
      local inPath = inPathBase .. tostring(shardNumber) .. '.serialized'
      print('inPath', inPath)
      assert(fileExists(inPath))
      return torch.load(inPath)
   end

   local function consolidateShard_1(shardNumber, consolidated)
      local shard = readShard(shardNumber)
      local count = 0
      for queryIndex, knnInfo in pairs(shard) do
         count = count + 1
         if isQueryIndex(queryIndex) then
            if knn.isKnnInfo(knnInfo) then
               consolidated[queryIndex] = knn.trim(knnInfo, arg.newSize)
            else
               print('bad knnInfo', shardNumber, count, tostring(knnInfo))
            end
         else
            print('bad queryIndex', shardNumber, count, tostring(queryIndex))
         end
      end
      shard = nil  -- try to assist the garbage collector
   end

   local function consolidateShard_2(shardNumber, consolidated, indicesFound)
      local count = 0
      for queryIndex, knnInfo in pairs(readShard(shardNumber)) do
         indicesFound[queryIndex] = true
         local trimmed = knn.trim(knnInfo, arg.newSize)
         count = count + 1
         consolidated.space.index[queryIndex] = trimmed.space.index
         consolidated.space.dSpace2[queryIndex] = trimmed.space.dSpace2
         consolidated.space.dTime2[queryIndex] = trimmed.space.dTime2
         consolidated.time.index[queryIndex] = trimmed.time.index
         consolidated.time.dSpace2[queryIndex] = trimmed.time.dSpace2
         consolidated.time.dTime2[queryIndex] = trimmed.time.dTime2
      end
      dp('count', count)
      return count
   end

   -- pick algorithm
   if arg.version == 1 then
      local consolidated = {}
      for shardNumber = 0, arg.nShards - 1 do
         consolidateShard(shardNumber, consolidated)
         print('readKnnInfoConsolidate', 'shardNumber', shardNumber, 'memoryUsed / 1e6', memoryUsed() / 1e6)
      end
      return consolidated
   elseif arg.version == 2 then
      local nQueryIndicesExpected = 1229434
      local nBytes = nQueryIndicesExpected * arg.newSize * 6 * 4 -- just for the Tensors
      dp('nBytes / 1e9', nBytes / 1e9)
      local consolidated = {
         space = {
            index = torch.IntTensor(nQueryIndicesExpected, arg.newSize),
            dSpace2 = torch.FloatTensor(nQueryIndicesExpected, arg.newSize),
            dTime2 = torch.FloatTensor(nQueryIndicesExpected, arg.newSize),
         },
         time = {
            index = torch.IntTensor(nQueryIndicesExpected, arg.newSize),
            dSpace2 = torch.FloatTensor(nQueryIndicesExpected, arg.newSize),
            dTime2 = torch.FloatTensor(nQueryIndicesExpected, arg.newSize),
         },
      }
      local nQueryIndices = 0
      local indicesFound = {}
      for shardNumber = 0, arg.nShards - 1 do
         local count = consolidateShard_2(shardNumber, consolidated, indicesFound)
         nQueryIndices = nQueryIndices + count
      end

      -- did we see the right number of indices?
      dp('nQueryIndices', nQueryIndices)
      dp('nQueryIndicesExpected', nQueryIndicesExpected)
      assert(nQueryIndices == nQueryIndicesExpected)

      -- were there any duplicate indices?
      local nIndicesFound = tableCount(indicesFound)
      dp('nIndicesFound', nIndicesFound)
      assert(nQueryIndices == nIndicesFound)

      return consolidated
   else
      error('bad arg.version = ' .. tostring(arg.version))
   end

   error('impossible')
end
