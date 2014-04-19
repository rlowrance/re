-- readKnnInfoConsolidated_test.lua
-- unit test

require 'fileDelete'
require 'fileExists'
require 'ifelse'
require 'readKnnInfoConsolidated'
require 'readViaSerializedFile'

local function test(useDebugFile)
   local inputDir = '../data/v6/output/'
   local inputFileBaseName = 'program_impute_knninfo_consolidate_shards_to_serialized_objects'
   local inputFileSuffix = '.serializedObjects'
   local inputFileName = inputFileBaseName .. inputFileSuffix
   local inputPath = inputDir .. inputFileName

   -- delete any cache
   local cachePath = inputPath .. '.serialized' 
   if fileExists(cachePath) then
      fileDelete(cachePath)
      print('deleted cache', cachePath)
      stop()
   end

   local args = {
      newSize = 256,
   }

   local usedCache, obj, msg = readViaSerializedFile(inputPath,
                                                     readKnnInfoConsolidated,
                                                     args)
   print('usedCache', usedCache)
   pp.table('obj', obj)
   print('msg', msg)

   error('write test')
end

local useDebugFile = true
--test(useDebugFile)
test(not useDebugFile)

print('ok readKnnInfoConsolidated')
