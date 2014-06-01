-- program_impute_knninfo_test_serialized.lua
-- test read and writing of serialized queryIndex and knnInfo

require 'equalObjectValues'
require 'pp'
require 'torch'

local queryIndex = 12345
local knnInfo = {
   space = {
      index = torch.IntTensor{1,2,3},
      dSpace2 = torch.rand(3),
      dTime2 = torch.rand(3),
   },
   time = {
      index = torch.IntTensor{1,2,3},
      dSpace2 = torch.rand(3),
      dTime2 = torch.rand(3),
   },
}

local function printBytes(s)
   for i = 1, #s do
      print(string.format('byte offset %d int %d', i, string.byte(s, i)))
   end
end

local function containsNewline(s)
   local newline = string.byte('\n', 1)
   for i = 1, #s do
      if string.byte(s, i) == newline then
         return true
      end
   end
   return false
end

local filePath = '/tmp/program_impute_knninfo_test_serialized.serializedStrings'

local outputFile, err = io.open(filePath, 'w')
if outputFile == nil then error(err) end

local queryIndexSerialized = torch.serialize(queryIndex)
print('queryIndex', queryIndex, 'queryIndexSerialized', queryIndexSerialized)
printBytes(queryIndexSerialized)
print(containsNewline(queryIndexSerialized))
print(#queryIndexSerialized)

outputFile:write(string.format('%d', #queryIndexSerialized))
outputFile:write(queryIndexSerialized)
--outputFile:write('\n')
assert(queryIndex == torch.deserialize(queryIndexSerialized))

local knnInfoSerialized = torch.serialize(knnInfo)
pp.table('knnInfo', knnInfo)
print('knnInfoSerialized', knnInfoSerialized)
printBytes(knnInfoSerialized)
print(containsNewline(knnInfoSerialized))

outputFile:write(string.format('%d', #knnInfoSerialized))
outputFile:write(knnInfoSerialized)
--outputFile:write('\n')
local s2 = torch.deserialize(knnInfoSerialized)
pp.table('s2', s2)

outputFile:close()

local inputFile, err = io.open(filePath, 'r')
if inputFile == nil then error(err) end

local nBytes = inputFile:read('*n')
print('nBytes', nBytes)
local record1 = inputFile:read(nBytes)
print('record1', record1)
assert(record1 ~= nil)
assert(record1 == queryIndexSerialized)
local queryIndex2 = torch.deserialize(record1)
print('queryIndex2', queryIndex2)
assert(queryIndex == queryIndex2)

local nBytes = inputFile:read('*n')
print('nBytes', nBytes)
local record2 = inputFile:read(nBytes)
print('record2', record2)
assert(equalObjectValues(record2, knnInfoSerialized))
local knnInfo2 = torch.deserialize(knnInfo2)
pp.table('knnInfo2', knnInfo2)
assert(equalObjectValues(knnInfo2, knnInfo))

inputFile:close()

print('done')
