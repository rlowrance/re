-- readViaSerializedFile_test.lua
-- unit test

require 'fileAssureNotExists'
require 'makeVp'
require 'pp'
require 'readViaSerializedFile'

local debug = false

local function makeFn(version)
   local function fn(what, path, args)
      if what == 'version' then
         return version
      end
      -- pretend to read the file
      return {
         field1 = args.field1,
         field2 = args.field2,
      }
   end

   return fn
end

local fnVersion1 = makeFn(1)
local fnVersion2 = makeFn(2)

local path = '/tmp/readViaSerializedFile_test.data'
local pathCache = path .. '.serialized'
fileAssureNotExists(pathCache)

local args = {
   field1 = 1,
   field2 = 2,
}

local usedCache, obj, msg = readViaSerializedFile(path, fnVersion1, args)
if debug then print(usedCache, obj, msg) pp.table('obj', obj) end
assert(not usedCache)
assert(obj.field1 == 1)
assert(obj.field2 == 2)
assert(msg == 'no cache file', msg)


local usedCache, obj, msg = readViaSerializedFile(path, fnVersion1, args)
assert(usedCache)
assert(obj.field1 == 1)
assert(obj.field2 == 2)
assert(msg == nil, msg)

args.field1 = 10
local usedCache, obj, msg = readViaSerializedFile(path, fnVersion1, args)
assert(not usedCache)
assert(obj.field1 == 10)
assert(obj.field2 == 2)
assert(string.sub(msg, 1, 3) == 'arg', msg)

local usedCache, obj, msg = readViaSerializedFile(path, fnVersion1, args)
assert(usedCache)
assert(obj.field1 == 10)
assert(obj.field2 == 2)
assert(msg == nil, msg)

local usedCache, obj, msg = readViaSerializedFile(path, fnVersion2, args)
assert(not usedCache)
assert(obj.field1 == 10)
assert(obj.field2 == 2)
assert(string.sub(msg, 1, 7) == 'version', msg)

print('ok readViaSerializedFile')
