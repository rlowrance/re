-- program_analyze_imputed_factors.lua
-- determine simple statistics of parcel factors we may want to impute

require 'isnan'
require 'pp'
require 'readParcelsForImputation'
require 'readViaSerializedFile'

local path = '../data/v6/output/parcels-sfr-geocoded.csv'
local args = {
   readlimit = 10,
   readlimit = -1,
}
local usedCache, result, msg = readViaSerializedFile(path, readParcelsForImputation, args)

print('*************************')
print('stdout from program_analyze_imputed_factors.lua')
print()
print('usedCache', usedCache)
print('msg', msg)

local nm = result.nm
local factorColumnNames = result.factorColumnNames
--pp.table('factorColumnNames', factorColumnNames)

local stats = {}
local function statsInit()
   return {
      values = {},
      missingCount = 0,
      nUnique = 0,
   }
end

local function statsTabulate(columnName, value)
   local stat = stats[columnName]
   assert(stat ~= nil)
   if isnan(value) then
      stat.missingCount = stat.missingCount + 1
   else
      if stat.values[value] then
         stat.values[value] = stat.values[value] + 1
      else
         stat.values[value] = 1
         stat.nUnique = stat.nUnique + 1
      end
   end
end

-- initialize stats table and table of column indices
local columnIndices = {}
pp.table('factorColumnNames', factorColumnNames)
for _, columnName in ipairs(factorColumnNames) do
   stats[columnName] = statsInit()
   columnIndices[columnName] = nm:columnIndex(columnName)
end

local nSamples = nm.t:size(1)
for sampleIndex = 1, nSamples do

   if sampleIndex % 100000 == 0 then
      print('processing sample index', sampleIndex)
   end

   for _, columnName in ipairs(factorColumnNames) do
      local value = nm.t[sampleIndex][columnIndices[columnName]]
      statsTabulate(columnName, value)
   end
end

for _, columnName in ipairs(factorColumnNames) do
   print('\n')
   print(columnName)
   local stat = stats[columnName]
   print('missing frequency', stat.missingCount / nSamples)
   print('number of unique values', stat.nUnique)
   if stat.nUnique < 20 then 
      for k, v in pairs(stat.values) do
         print('value', k, 'is present', v)
      end
   end
end

print('************* end of stdout')
