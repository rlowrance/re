-- readViaSerializedFile.lua
-- USE CASE: you repeatedly read the same file and want to speed that up

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

-- read a file and transform it or the corresponding serialized transformation
-- ARGS:
-- pathCache : string, path to cache file
-- fn        : function(what, path, args) --> obj or version number
--             function to read the file at path and transform it using the args into an arbitrary object
--             where
--             what : string in {'version', 'object'}
--             args : table
-- args      : table of arguments to fn
-- RETURNS
-- usedCache : boolean, true iff the value in the cache was used 
-- obj       : object created by fn(path, 'readAndTransform', args)
-- msg       : string, if not usedCache, why
-- SIDE EFFECTS:
-- Creates cache containing the results of transforming the input
function readViaSerializedFile(pathCache, fn, args)
   assert(type(pathCache) == 'string')
   assert(type(fn) == 'function')
   assert(type(args) == 'table')

   print('pathCache', pathCache)
   if fileExists(pathCache) then
      local diskObj = torch.load(pathCache, 'binary')
      assert(type(diskObj) == 'table')

      -- check function version
      local fnVersion = fn('version', path, args)
      if diskObj.fnVersion ~= fnVersion then
         return false, readAndWriteCache(fn, args, pathCache), msgVersion(diskObj.version, fnVersion)
      end

      -- check value of each arg
      local equal = equalObjectValues(diskObj.args, args)
      if not equal then
         return false, readAndWriteCache(fn, args, pathCache), msgArgs(diskObj.args, args, 'diskobj.Args', 'args')
      end

      -- function version and all args are equal, so return version on disk
      return true, diskObj.value
   else
      return false,  readAndWriteCache(fn, args, pathCache), 'no cache file'
   end
end
