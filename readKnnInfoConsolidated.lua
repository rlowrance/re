-- readKnnInfoConsolidated.lua

require 'knn'
require 'memoryUsed'
require 'torch'

-- read file program_impute_knninfo_consolidate_shards_to_serialized_objects[_debug].serializedObjects
-- ARGS:
-- what  : string in {'version', 'object'}
-- path  : string, path to the input file
-- args  : table with these fields
--         .newSize : integer > 0, each knnInfo is shortened to this size (<= 1024)
-- RETURNS
-- result : version number or object
function readKnnInfoConsolidated(what, path, args)
   local debug = true   
   if debug then print('readKnnInfoConsolidated', what, path, args) end

   if what == 'version' then
      return 3
   end

   local inputFile = torch.DiskFile(path, 'r')
   assert(inputFile)

   local knnInfos = {}
   local inputRecordCount = 0
   repeat  -- find a queryIndex followed by an knnInfo
      inputRecordCount = inputRecordCount + 1

      -- read until we find a queryIndex (which is a number)
      local queryIndex
      repeat
         queryIndex = inputFile:readObject()
         if type(queryIndex) ~= 'number' then
            print('queryIndex not a number', inputRecordCount, queryIndex(type), queryIndex)
         end
      until type(queryIndex) == 'number' or type(queryIndex) == 'nil'

      if queryIndex == nil then
         break
      end

      -- read until we find a knnInfo
      local knnInfo
      repeat
         knnInfo = inputFile:readObject()
         if not knn.isKnnInfo(knnInfo) then
            print('not q knnInfo', inputRecordCount, queryIndex, tostring(knnInfo))
         end
      until knn.isKnnInfo(knnInfo)


      knnInfos[queryIndex] = knn.trim(knnInfo, args.newSize)

      -- maybe help the garbage collector
      queryIndex = nil
      knnInfo = nil

      if inputRecordCount % 1000 == 0 then
         local used = memoryUsed()  -- collect garbage
         print('inputRecordCount', inputRecordCount, 'memory used/1e6', used / 1e6)
      end
   until false

   return knnInfos
end
