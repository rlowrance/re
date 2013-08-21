require 'ifelse'
require 'makeVp'
require 'readParcelsSfrGeocoded'
require 'startLogging'
require 'validateAttributes'

--read parcels-sfr-geocoded.csv and produce txt files containing known and 
--unknown features. Columns in the text file are
-- Column 1    --> apn.recoded
-- Column 2    --> YEAR.BUILT
-- Column last --> code (as string)
-- ARGS:
-- code : string, name of code feature
-- RETURNs: nil
function parcelsCodeKnown(code)
   local vp = makeVp(2, 'parcelsCodeKnown')
   validateAttributes(code, 'string')

   -- setup file paths
   local dirOutput = '../data/v6/output/'
   local pathToParcels = dirOutput .. 'parcels-sfr-geocoded.csv'
   local basename = 'parcels-' .. code
   local pathToKnown = dirOutput .. basename .. '-known.csv'
   local pathToUnknown = dirOutput .. basename .. '-unknown.csv'
   local pathToUnknownFields = dirOutput .. basename .. '-unknown-fields.csv'
   local pathToLogFile = dirOutput .. 'parcels-' .. code .. '-known.log'

   torch.manualSeed(20110513)
   startLogging(pathToLogFile, arg)  -- arg are the command line arguments
   vp(0, 'paths to files')
   vp(1, 
      'pathToParcels', pathToParcels,
      'pathToKnown', pathToKnown,
      'pathToUnknown', pathToUnknown,
      'pathToLogFile', pathToLogFile)

   local readLimit = 1000
   readLimit = -1  -- read all the parcels
   if readLimit ~= -1 then
      vp(0, "RERUN: DID NOT READ ALL THE INPUT")
   end
   local parcels = readParcelsSfrGeocoded(pathToParcels, readLimit, code)
   vp(2, 'parcels', parcels)

   local function open(path)
      local f, msg = io.open(path, 'w')
      if f == nil then
         errro(msg)
      end
      return f
   end

   local featureNames = {'apn.recoded',
                         'YEAR.BUILT',
                         'LAND.SQUARE.FOOTAGE',
                         'TOTAL.BATHS.CALCULATED',
                         'BEDROOMS',
                         'PARKING.SPACES',
                         'UNIVERSAL.BUILDING.SQUARE.FEET',
                         'G LATITUDE',
                         'G LONGITUDE'}

   -- start the known file
   local known = open(pathToKnown)
   -- write header
   for i, featureName in ipairs(featureNames) do
      if i > 1 then known:write(',') end
      known:write(featureName)
   end
   known:write(',' .. code)
   known:write('\n')

   -- start the unknown file
   local unknown = open(pathToUnknown)
   -- write file with names of fields
   -- We don't want a header in the unknown file because it will be split into slices
   -- by Hadoop and then most of the slices would not see the header.
   local unknownFields = open(pathToUnknownFields)
   for i, featureName in ipairs(featureNames) do
      unknownFields:write(featureName .. '\n')
   end
   unknownFields:close()

   -- column numbers for feature fields
   local featureColumnNumber = {}
   for _, featureName in ipairs(featureNames) do
      table.insert(featureColumnNumber, parcels:columnIndex(featureName))
   end
   vp(2, 'featureColumnNumber', featureColumnNumber)
   local codeColumnNumber = parcels:columnIndex(code)
   vp(2, 'codeColumnNumber', codeColumnNumber)

   local function isInt(x)
      if math.floor(x) == x then
         return x
      else
         error('x (' .. tostring(x) .. ') is not an int')
      end
   end

   -- formatted record containing all the features for record number i
   local function record(i)
      local vp = makeVp(0, 'record')
      vp(1, 'i', i)
      local s = ''
      for col = 1, #featureNames do
         if col > 1 then s = s .. ',' end
         s = s .. string.format(ifelse(col < 8, '%d', '%f'), 
                                parcels.t[i][featureColumnNumber[col]])
      end
      vp(1, 's', s)
      return s
   end

   local function writeToUnknown(i)
      local rec = record(i) 
      unknown:write(rec .. '\n')
   end

   local function writeToKnown(i)
      local vp = makeVp(0, 'writeToKnown')
      vp(2, 'parcels.levels', parcels.levels)
      vp(2, 'parcels.t[i]', parcels.t[i])
      local codeString = parcels.levels[code][parcels.t[i][codeColumnNumber]]
      local rec = record(i) .. ',' .. codeString
      known:write(rec .. '\n')
   end
      
   local nKnown = 0
   local nUnknown = 0
   for i = 1, parcels.t:size(1) do
      if isnan(parcels.t[i][codeColumnNumber]) then
         nKnown = nKnown + 1
         writeToUnknown(i)
      else
         nUnknown = nUnknown + 1
         writeToKnown(i)
      end
   end

   vp(0, 'nKnown', nKnown)
   vp(0, 'nUnknown', nUnknown)

   known:close()
   unknown:close()
end