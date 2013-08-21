-- main program to create files needed for imputation for a specific code
-- 
-- INPUT FILE:
-- parcels-sfr-geocoded.csv
-- 
-- OUTPUT FILES:
-- parcels-CODE-unknown.pairs     (apn|features)
-- parcels-CODE-known-test.pairs  (apn|features,code)
-- parcels-CODE-known-val.pairs   (apn|features,code)
-- parcels-CODE-known-train.pair  (apn|features,code)
--
-- COMMAND LINE ARGUMENTS
-- --code STRING : name of code (e.g., HEATING.CODE)
--
-- NOTES
-- 1. A pairs file has records fields \t fields
--    where the fields are comma separated values
-- 2. The features are fixed. They are the 8 features used in imputation.
-- 3. To create a file with all known observations, just cat the 3 subsets
--    cat parcels-CODE-known-test.pairs \
--        parcels-CODE-known-val.pairs \
--        parcels-CODE-known-train.pairs
-- 4. The known observations are split randomly into test/val/train at 
--    20% / 20% / 60% .

require 'attributesLocationsTargetsApns'
require 'isnan'
require 'Log'
require 'makeVp'
require 'parseCommandLine'
require 'readParcelsSfrGeocoded'
require 'validateAttributes'


-------------------------------------------------------------------------------
-- DEFINE LOCAL FUNCTIONS
-------------------------------------------------------------------------------

-- return table
local function parse(arg)
   local vp = makeVp(0, 'parse')
   validateAttributes(arg, 'table')
   local result = {}
   result.code = parseCommandLine(arg, 'value', '--code')
   validateAttributes(result.code, 'string')
   vp(1, 'result', result)
   return result
end

-- return open Log 
local function makeLog(code, outputDir)
   validateAttributes(code, 'string')
   validateAttributes(outputDir, 'string')
   local logFileName = string.format('parcels-pairs-log-%s.txt',
                                     code)
   local log = Log(outputDir .. logFileName)
   return log
end

-- open file in write mode
local function openFile(code, basename, outputDir)
   local vp = makeVp(0, 'openFile')
   validateAttributes(code, 'string')
   validateAttributes(basename, 'string')
   validateAttributes(outputDir, 'string')
   local filename = string.format('parcels-%s-%s.pairs', code, basename)
   local filepath = outputDir .. filename
   vp(2, 'filepath', filepath)
   local f = io.open(filepath, 'w')
   if f == nil then
      error('unable to open ' .. filepath)
   end
   return f
end

-- return 'test', 'val', 'train' in 20% 20% 60% of calls
local function nextKind()
   local vp = makeVp(0, 'nextKind')
   local fractionTest = .2
   local fractionVal = .2 + fractionTest
   local r = torch.uniform(0,1)
   vp(2, 'fractionTest', fractionTest, 'fractionVal', fractionVal, 'r', r)
   if r < fractionTest then
      return 'test'
   elseif r < fractionVal then
      return 'val'
   else
      return 'train'
   end
end

-- concatenate and insert commas into the 8 feature fields
local function concat(tensor)
   local vp = makeVp(0, 'concat')
   vp(1, 'tensor', tensor)
   validateAttributes(tensor, 'Tensor', '1d', 'size', {8})
   local s = string.format('%f,%f,%f,%f,%f,%f,%f,%f',
                           tensor[1],
                           tensor[2],
                           tensor[3],
                           tensor[4],
                           tensor[5],
                           tensor[6],
                           tensor[7],
                           tensor[8])
   return s
end
   
local function writeApnFeature(file, apn, features)
   local vp = makeVp(0, 'writeApnFeature')
   vp(1, 'apn', apn)
   validateAttributes(file, 'file')
   validateAttributes(apn, 'number', '>', 0)
   validateAttributes(features, 'Tensor', '1d')
   file:write(tostring(apn) .. '\t' .. concat(features) .. '\n')
end

local function writeApnFeatureCode(file, apn, features, code)
   local vp = makeVp(0, 'writeApnFeatureCode')
   vp(1, 'file', file)
   vp(1, 'apn', apn)
   vp(1, 'features', features)
   vp(1, 'code', code)
   validateAttributes(file, 'file')
   validateAttributes(apn, 'number', '>', 0)
   validateAttributes(features, 'Tensor', '1d')
   validateAttributes(code, 'string')
   file:write(tostring(apn) .. '\t' .. concat(features) .. ',' .. code .. '\n')
end


-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local function main()
   local vp = makeVp(0, 'main')
   torch.manualSeed(123)
   local clArgs = parse(arg)
   vp(1, 'clArgs', clArgs)
   local outputDir = '../data/v6/output/'
   local log = makeLog(clArgs.code, outputDir)

   local readLimit = -1
   --local readLimit = 1000  -- while debugging
   local parcels = 
      readParcelsSfrGeocoded(outputDir .. 'parcels-sfr-geocoded.csv',
                             readLimit,
                             clArgs.code)
   local split = -- split parcels into 4 NamedMatrix objs
      attributesLocationsTargetsApns(parcels, clArgs.code)
   local features = split.attributes
   local codes = split.targets
   local apns = split.apns
   vp(2, 'features.t size', features.t:size())
   assert(features.t:size(2) == 8)
   
   local unknown = openFile(clArgs.code, 'unknown', outputDir)
   local knownTest = openFile(clArgs.code, 'known-test', outputDir)
   local knownVal = openFile(clArgs.code, 'known-val', outputDir)
   local knownTrain = openFile(clArgs.code, 'known-train', outputDir)
   
   local nUnknown, nKnownTest, nKnownVal, nKnownTrain = 0, 0, 0, 0
   vp(2, 'codes', codes)
   local codeLevels = codes.levels[clArgs.code]
   vp(2, 'codeLevels', codeLevels)
   for i = 1, apns.t:size(1) do
      local codeNumber = codes.t[i][1]  -- apns.t is 2D!
      vp(2, 'codeNumber', codeNumber, 'isnan', isnan(codeNumber))
      if isnan(codeNumber) then
         writeApnFeature(unknown, apns.t[i][1], features.t[i])
         nUnknown = nUnknown + 1
      else
         local codeString = codeLevels[codeNumber]
         vp(2, 'codeString', codeString)
         validateAttributes(codeString, 'string')
         local kind = nextKind()
         vp(2, 'kind', kind)
         if kind == 'test' then
            writeApnFeatureCode(knownTest, apns.t[i][1], features.t[i], codeString)
            nKnownTest = nKnownTest + 1
         elseif kind == 'val' then
            writeApnFeatureCode(knownVal, apns.t[i][1], features.t[i], codeString)
            nKnownVal = nKnownVal + 1
         elseif kind == 'train' then
            writeApnFeatureCode(knownTrain, apns.t[i][1], features.t[i], codeString)
            nKnownTrain = nKnownTrain + 1
         else  
            error('bad kind ' .. tostring(kind))
         end
      end
   end

   unknown:close()
   knownTest:close()
   knownVal:close()
   knownTrain:close()

   log:log('wrote %d records to %s', nUnknown, 'unknown')
   log:log('wrote %d records to %s', nKnownTest, 'knownTest')
   log:log('wrote %d records to %s', nKnownVal, 'knownVal')
   log:log('wrote %d records to %s', nKnownTrain, 'knownTrain')

   log:close()
end

main()
