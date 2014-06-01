-- program_impute_knninfo_make_consolidated_shards.lua

error('deprecated: don't consolidate the 100 shards, just read them directly')

-- COMMAND LINE ARGS
-- [--dataDir path/to/directory]
-- INPUT FILES
-- ../data/v6/output/program_impute_knninfo_make_share_N.serialized
--   for N - 0 up to 99 
-- OUTPUT FILES
-- ../data/v6/output/knninfo_consolidated_shards.serialized
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
require 'tableMapValues'
require 'tensor'
require 'time'
 
local function parseCommandLine(args)--{{{
   assert(#args >= 0, 'command line args: [--dataDir path]')
   pp.table('args', args)
   local cl = CommandLine(args)
   local splitProgramName = splitString(args[0], '.')
   assert(splitProgramName[2] == 'lua')
   local result = {
      me = splitProgramName[1],
      piece = cl:required('--piece'),
      dataDir = cl:defaultable('--dataDir', '../data/v6/output/'),
   }
   result.piece = tonumber(result.piece)
   assert(1 <= result.piece and result.piece <= 3, tostring(result.piece))

   return result
end--}}}

-- toSorterTensor(): convert tensors to torch.FloatTensor--{{{
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
end--}}}

-- trim(): shorten the sequence of tensors--{{{
local function trim(knnInfo, newSize)

   -- keep just the first newSize elements
   local function keepPrefix(v)
      local typename = torch.typename(v)
      assert(typename == 'torch.FloatTensor' or typename == 'torch.IntTensor')
      local constructor = ifelse(typename == 'torch.FloatTensor', torch.FloatTensor, torch.IntTensor)
      local result = constructor(v:storage(), 1, newSize, 1)
      return result
   end

   return tableMapValues(knnInfo, keepPrefix)
end--}}}

-- isQueryIndex(): return true or false--{{{
local function isQueryIndex(value)
   return type(value) == 'number' and value >= 1
end--}}}

-- consolidate(): append a serialied representation of all knnInfos to output file--{{{
local function consolidate(shardNumber, outputObject, config, actionFn)
   local inPath = config.inputDir .. config.baseInputFileName .. tostring(shardNumber) .. '.serialized'
   --print('inPath', inPath)
   if fileExists(inPath) then
      local shard = torch.load(inPath)
      local count = 0
      for queryIndex, knnInfo in pairs(shard) do
         count = count + 1
         if isQueryIndex(queryIndex) then
            if knn.isKnnInfo(knnInfo) then
               actionFn(queryIndex, knnInfo, outputObject)
            else
               print('bad knnInfo', shardNumber, count, tostring(knnInfo))
            end
         else
            print('bad queryIndex', shardNumber, count, tostring(queryIndex))
         end
      end
      shard = nil  -- try to assist the garbage collector
      return count
   else
      error(string.format('did not find shard %d', shardNumber))
   end
end--}}}

-- openAndPositionOutputfile()--{{{
-- return torch.DiskFile at end position
local function openAndPositionOutputfile(cl, config)
   local outputFile
   if cl.piece == 0 then
      outputFile = torch.DiskFile(config.outputPath, 'w')
   else
      outputFile = torch.DiskFile(config.outputPath, 'rw')
      outputFile:seekEnd()
   end
   assert(outputFile)
   return outputFile
end--}}}

-- writePairs() for each of the 1.2 million knnInfos--{{{
local function writePairs(cl, config)
   assert(type(cl.piece) == 'string')
   cl.piece = tonumber(cl.piece)
   assert(cl.piece >= 1)
   assert(cl.piece <= 3)

   local function actionWritePairObject(queryIndex, knnInfo, outputFile)
      local obj = {queryIndex, trim(knnInfo, config.trimmedSize)}
      outputFile:writeObject(obj)  -- writeObject() has a memory leak
   end
   
   local outputFile = openAndPositionOutputfile(cl, config)

   local pieces = {
      {0, 33},
      {34, 66},
      {67, 99},
   }

   local pair = pieces[cl.piece]
   local first, last = pair[1], pair[2]
   print(first, last)

   for shardNumber = first, last do
      local nRecords = consolidate(shardNumber, outputFile, config, actionWritePairObject)
      print(string.format('wrote %d records from shard %d', nRecords, shardNumber))
      local bytesUsed = memoryUsed()
      print('bytesUsed / 10^6', bytesUsed / 1e6)
   end
end--}}}

-- accumulate() into three large tables and write--{{{
-- NOTE: result is "not enough memory" when writing 50 shards at once
-- NOTE: can write 33 shards at once
local function accumulate(cl, config)
   local function actionSave(queryIndex, knnInfo, consolidated)
      consolidated[queryIndex] = knnInfo
   end

   local function consolidateShards(from, to, outputFile)
      local consolidated = {}
      for shardNumber = from, to do
         print('consolidating', shardNumber)
         consolidate(shardNumber, consolidated, config, actionSave)
         local used = memoryUsed() -- collect garbage as well 
         print('memory used / 1e6', used / 1e6)
      end
      print('writing consolidated table to outputFile')
      outputFile:writeObject(consolidated)
   end

   
   local outputFile = openAndPositionOutputfile(cl, config)
   if cl.piece == 1 then
      consolidateShards(0, 33, outputFile) 
   elseif cl.piece == 2 then
      consolidateShards(34, 67, outputFile)
   elseif cl.piece == 3 then
      consolidateShards(68, 99, outputFile)
   else
      error(tostring(cl.piece))
   end
end--}}}


-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local cl = parseCommandLine(arg)
pp.table('cl', cl)
cl.piece = tonumber(cl.piece)
assert(cl.piece >= 1)
assert(cl.piece <= 3)

local knnInfoDir = 'knnInfo/'
local config = {
   nShards = 1,  -- for now
   nShards = 100,
   gcFrequency = 1,
   gcFrequency = 10,
   baseInputFileName = 'program_impute_knninfo_make_shard_',
   inputDir = '/media/3AD2D839D2D7F75B/nyu-thesis-project/', -- on isolde
   inputDir = cl.dataDir .. knnInfoDir .. 'impute-shards/',
   outputDir = cl.dataDir .. knnInfoDir, 
   outputFileName = 'knninfo_consolidated_shards.serialized',
   trimmedSize = 512, -- not enough memory
   trimmedSize = 256, -- not enough memory
   trimmedSize = 1, -- not enough memory !
   -- above failures are attributed to a memory leak in torch.writeObject()
   trimmedSize = 1024,
   debug = true,
   debug = false,
   algo = 'writePairs',
   algo = 'accumulate',
}
config.outputPath = config.outputDir .. config.outputFileName

pp.table('config', config)

if config.algo == 'writePairs' then
   writePairs(cl, config)
elseif config.algo == 'accumulate' then
   accumulate(cl, config)
else
   error('config.algo', tostring(config.algo))
end


-- there is no API to close the DiskFile

if config.debug then
   print('DEBUGGING')
end

print('done')
