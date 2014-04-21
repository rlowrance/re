-- cachedComputation2.lua
-- USE CASE: you perform a computation on a large data set and want to save the results
-- NOTE: if the data set is small, you can use cachedComputation, which is safer

require 'equalObjectValues'
require 'fileExists'
require 'makeVp'
require 'memoryUsed'
require 'pp'
require 'tableCopy'
require 'tableCount'
require 'tableSplit'
require 'torch'

local function readCache(pathCache)
   local file = torch.DiskFile(pathCache, 'r')
   assert(file)

   local s = file:readObject()
   assert(s == 'fnVersion')
   local fnVersion = file:readObject()

   local s = file:readObject()
   assert(s == 'args')
   local args = file:readObject()

   local allValues = {}
   repeat
      local s = file:readObject()
      if s ~= 'value' then 
         break
      end
      local t = file:readObject()
      for k, v in pairs(t) do
         allValues[k] = v
      end
   until false

   local result = {
      fnVersion = fnVersion,
      args = args,
      values = allValues,
   }

   return result
end

local function writeTable(file, fieldName, t)
   local threshold = 400000  -- much larger values result in luajit out of memory
   local threshold = 200000
   local threshold = 10000
   local threshold = 5000
   local size = tableCount(t)
   if size > threshold then
      print('writeTable', 'threshold', threshold, 'size', size)
      local t1, t2 = tableSplit(t)
      writeTable(file, fieldname, t1)
      t1 = nil
      writeTable(file, fieldname, t2)
      t2 = nil
      t = nil
   else
      print('writeTable', 'memoryUsed / 1e6', memoryUsed() / 1e6)
      file:writeObject(fieldName)
      file:writeObject(t)
      t = nil
   end
end

local function writeCache(diskObj, pathCache)
   local file = torch.DiskFile(pathCache, 'w')

   file:writeObject('fnVersion')
   file:writeObject(diskObj.key)

   file:writeObject('args')
   file:writeObject(diskObj.args)

   writeTable(file, 'value', diskObj.value)
end

local function readAndWriteCache(fn, args, pathCache)
   local obj = fn('object', args)
   local diskObj = {
      fnVersion = fn('version', args),
      args = args,
      value = obj,
   }
   print('readAndWriteCache:about to write cache', 'memoryUsed / 1e6', memoryUsed() / 1e6)
   writeCache(diskObj, pathCache)
   return obj
end

local function msgArgs(t1, t2, t1Name, t2Name)
   local function testEach(t1, t2, t1Name, t2Name)
      for k, v in pairs(t1) do
         if t2[k] == nil then
            return string.format('arg difference: %s[%s] exists %s[%s] does not exist', t1Name, tostring(k), t2Name, tostring(k))
         end
         if t2[k] ~= v then
            return string.format('arg difference: %s[%s] = %s %s[%s]=%s', t1Name, tostring(k), tostring(v), t2Name, tostring(k), tostring(t2[v]))
         end
      end
   end

   local msg = testEach(t1, t2, t1Name, t2Name)
   if msg ~= nil then
      return msg
   end
   return testEach(t2, t1, t2Name, t1Name)
end

local function msgVersion(diskObjVersion, fnVersion)
   return string.format('version difference: disk %s fn %s', tostring(diskObjVersion), tostring(fnVersion))
end

 ----------------------------------------------------------------------
 -- implementation 1 : use torch native cache format
 ----------------------------------------------------------------------

local implementation_1 = {}

function implementation_1.writeDiskObj(file, diskObj)
   file:writeObject(diskObj)
end

function implementation_1.readDiskObj(file)
   return file:readObject()
end

 ----------------------------------------------------------------------
 -- implementation 2 : cache file content dependents on the result of fn(arg)
 --   fnVersion
 --   arg
 --   1D int tensor of query indices
 --   2D int tensor of index values
 --   2D float tensor of distance values
 ----------------------------------------------------------------------

local implementation_2 = {}

function implementation_2.writeDiskObj(file, diskObj)
   local debug = false
   local function dp(a, b) if debug then print(a, b) end end
   local n = tableCount(diskObj.value)
   dp('n', n)

   local function numberNeighbors(t)
      for queryIndex, knnInfo in pairs(t) do
         return knnInfo.space.index:size(1)
      end
   end

   local function getQueries(t)
      local result = torch.IntTensor(n)
      local index = 0
      for queryIndex, knnInfo in pairs(t) do
         index = index + 1
         result[index] = queryIndex
      end
      assert(index == n)
      return result
   end

   local function getIndices(t)
      local result = torch.IntTensor(n * 2, numberNeighbors(t))
      local index = 0
      for queryIndex, knnInfo in pairs(t) do
         index = index + 1
         result[index] = knnInfo.space.index
         index = index + 1
         result[index] = knnInfo.time.index
      end
      assert(index == 2 * n)
      return result
   end

   local function getDistances(t)
      local result = torch.IntTensor(n * 4, numberNeighbors(t))
      local index = 0
      for queryIndex, knnInfo in pairs(t) do
         index = index + 1
         result[index] = knnInfo.space.dSpace2
         index = index + 1
         result[index] = knnInfo.space.dTime2
         index = index + 1
         result[index] = knnInfo.time.dSpace2
         index = index + 1
         result[index] = knnInfo.time.dTime2
      end
      assert(index == 4 * n)
      return result
   end

   file:writeObject(diskObj.fnVersion)
   file:writeObject(diskObj.arg)

   file:writeObject(getQueries(diskObj.value))
   local used = memoryUsed()
   dp('writeDiskObj after getQueries memory used / 1e6', used / 1e6)

   file:writeObject(getIndices(diskObj.value))
   local used = memoryUsed()
   dp('writeDiskObj after getQueries memory used / 1e6', used / 1e6)

   file:writeObject(getDistances(diskObj.value))
   local used = memoryUsed()
   dp('writeDiskObj after getQueries memory used / 1e6', used / 1e6)
end

function implementation_2.readDiskObj(file)
   local debug = false
   local function dp(a, b) if debug then print('readDiskObj', a, b) end end

   local function makeValue(queriesIndices, knnInfoIndices, knnInfoDistances)

      local nextKnnInfoIndicesIndex = 0
      local nextKnnInfoDistancesIndex = 0
      local function makeKnnInfo()
         local knnInfo = {
            space = {},
            time = {},
         }

         nextKnnInfoIndicesIndex = nextKnnInfoIndicesIndex + 1
         knnInfo.space.index = knnInfoIndices[nextKnnInfoIndicesIndex]

         nextKnnInfoIndicesIndex = nextKnnInfoIndicesIndex + 1
         knnInfo.time.index = knnInfoIndices[nextKnnInfoIndicesIndex]

         nextKnnInfoDistancesIndex = nextKnnInfoDistancesIndex + 1
         knnInfo.space.dSpace2 = knnInfoDistances[nextKnnInfoDistancesIndex]
         
         nextKnnInfoDistancesIndex = nextKnnInfoDistancesIndex + 1
         knnInfo.space.dTime2 = knnInfoDistances[nextKnnInfoDistancesIndex]

         nextKnnInfoDistancesIndex = nextKnnInfoDistancesIndex + 1
         knnInfo.time.dSpace2 = knnInfoDistances[nextKnnInfoDistancesIndex]
         
         nextKnnInfoDistancesIndex = nextKnnInfoDistancesIndex + 1
         knnInfo.time.dTime2 = knnInfoDistances[nextKnnInfoDistancesIndex]
      end

      local consolidated = {}
      for i = 1, queriesIndices:size(1) do
         dp('i', i)
         local queryIndex = queriesIndices[i]
         local knnInfo = makeKnnInfo()
         consolidated[queryIndex] = knnInfo
         -- not out of memory with statement below enabled
         dp('memory Used / 1e6', memoryUsed() / 1e6)
      end
   end

   local fnVersion = file:readObject()
   local arg = file:readObject()

   dp('memory used / 1e6', memoryUsed() / 1e6)
   dp('reading queriesIndices')
   local queriesIndices = file:readObject()

   dp('memory used / 1e6', memoryUsed() / 1e6)
   dp('reading knnInfoIndices')
   local knnInfoIndices = file:readObject()
  
   dp('memory used / 1e6', memoryUsed() / 1e6)
   dp('reading knnInfoDistances')
   local knnInfoDistances = file:readObject()

   local result = {
      fnVersion = fnVersion,
      arg = arg,
      value = makeValue(queriesIndices, knnInfoIndices, knnInfoDistances),
   }

   return result
end

 ----------------------------------------------------------------------
 -- implementation 3 : cache file content
 --   fnVersion
 --   arg
 --   queryIndex for first consolidated value
 --   knnInfo for first consolidated value
 --   queryIndex for second consolidated value
 --   knnInfo for second consolidated value
 --   ...
 ----------------------------------------------------------------------

local implementation_3 = {}

function implementation_3.writeDiskObj(file, diskObj)
   error('write me')
   local debug = true
   local function dp(a, b, c, d) if debug then print(a, b) end end

   file:writeObject(diskObj.fnVersion)
   file:writeObject(diskObj.arg)

   for queryIndex, knnInfo in pairs(diskObj.value) do
      file:writeObject(queryIndex)
      file:writeObject(knnInfo)
   end

end

function implementation_3.readDiskObj(file)
   error('write me')
end

-- dispatch to current implementation

local diskObjectImplementations = {
   implementation_1,
   implementation_2,
   implementation_3,
}

local function writeDiskObj(pathToCache, diskObj, cache_implementation)
   local file = torch.DiskFile(pathToCache, 'w')
   file:writeObject(cache_implementation)
   diskObjectImplementations[cache_implementation].writeDiskObj(file, diskObj)
   file:close()
end

local function readDiskObj(pathToCache, cache_implementation)
   local file = torch.DiskFile(pathToCache, 'r')
   local cache_implementation = file:readObject()
   assert(type(cache_implementation) == 'number')
   local result = diskObjectImplementations[cache_implementation].readDiskObj(file)
   file:close()
   return result
end

-- read a file and transform it or the corresponding serialized transformation
-- ARGS:
-- pathToCache    : string, path to cache file
-- fn             : function(arg) --> obj or version number
--                  if arg == nil, return version number
--                  if arg ~= nil, return arbitary object
-- arg            : non-nil argument to fn, possible a table
-- implementation : optional number, if present, overrides cache_implementation variable
--                  if not present, uses cache_implementation 1
-- RETURNS
-- obj            : object returned by fn(arg)
-- info           : table of information
--                  .how : string describing if cache was used, in {'used cache', 'from scratch'}
--                  .whyFromScratch : string if how == 'from scratch'
--                  .diskObj        : table if how == 'used cache' (intended for debugging)
-- SIDE EFFECTS:
-- Creates cache containing the results fn(arg)
function cachedComputation2(pathToCache, fn, arg, implementation)
   assert(type(pathToCache) == 'string')
   assert(type(fn) == 'function')
   assert(type(arg) == 'table')

   local cache_implementation = 1  -- default is general purpose but may run out of memory
   if type(implementation) == 'number' then
      cache_implementation = implementation
   end

   print('pathToCache', pathToCache)

   local whyFromScratch = nil
   local diskObj = nil

   -- attempt to use value in cache
   if fileExists(pathToCache) then
      diskObj = readDiskObj(pathToCache, cache_implementation)
      assert(type(diskObj) == 'table')

      -- check function version

      if diskObj.fnVersion == fn(nil) then
         if equalObjectValues(diskObj.arg, arg) then
            return diskObj.value, {how = 'used cache', diskObj = diskObj}
         else
            whyFromScratch = 'arg difference'
         end
      else
         whyFromScratch = 'version difference'
      end
   end

   -- compute value from scratch
   local value = fn(arg)
   local diskObj = {
      fnVersion = fn(nil),
      arg = arg,
      value = value,
   }
   writeDiskObj(pathToCache, diskObj, cache_implementation)
   return value, {how = 'from scratch', whyFromScratch = whyFromScratch}
end
