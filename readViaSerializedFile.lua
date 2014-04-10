-- readViaSerializedFile.lua
-- USE CASE: you repeatedly read the same file and want to speed that up

require 'equalObjectValues'
require 'fileExists'
require 'makeVp'
require 'pp'
require 'tableCopy'
require 'torch'

local function readAndWriteCache(path, fn, args, pathCache)
   local obj = fn('object', path, args)
   local diskObj = {
      fnVersion = fn('version', path, args),
      args = tableCopy(args),
      value = obj,
   }
   torch.save(pathCache, diskObj, 'binary')
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
-- path : string, path to file
-- fn   : function(what, path, args) --> obj or version number
--        function to read the file at path and transform it using the args into an arbitrary object
--        where
--        what : string in {'version', 'object'}
--        path : string
--        args : table
-- args : table of arguments
-- RETURNS
-- usedCache : boolean, true iff the value in the cache was used 
-- obj       : object created by fn(path, 'readAndTransform', args)
-- msg       : string, if not usedCache, why
-- SIDE EFFECTS:
-- . Creates file path .. '.serialized'
function readViaSerializedFile(path, fn, args)
   local pathCache = path .. '.serialized'
   if fileExists(pathCache) then
      local diskObj = torch.load(pathCache, 'binary')
      assert(type(diskObj) == 'table')

      -- check function version
      local fnVersion = fn('version', path, args)
      if diskObj.fnVersion ~= fnVersion then
         return false, readAndWriteCache(path, fn, args, pathCache), msgVersion(diskObj.version, fnVersion)
      end

      -- check value of each arg
      local equal = equalObjectValues(diskObj.args, args)
      if not equal then
         return false, readAndWriteCache(path, fn, args, pathCache), msgArgs(diskObj.args, args, 'diskobj.Args', 'args')
      end

      -- function version and all args are equal, so return version on disk
      return true, diskObj.value
   else
      return false,  readAndWriteCache(path, fn, args, pathCache), 'no cache file'
   end
end
