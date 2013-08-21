-- parcels-missing-codes-analysis.lua
-- main program to create analysis of missing codes in the SFR geocoded file
-- INPUT FILES
-- OUTPUT/parcels-sfr-geocoded.csv : all single family residential (SFR) parcels
--                                   that could be geocoded. All fields.
-- OUTPUT FILES
-- OUTPUT/parcels-missing-codes-analysis.csv : 
--   csv file showing frequency that codes are present and absent
--   This file can be used to determine which missing codes to impute.
-- COMMAND LINE PARAMETERS: NONE

require 'bestApns'
require 'hasNaN'
require 'makeVp'
require 'memoryUsed'
require 'NamedMatrix'
require 'startLogging'

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------

-- return sequence containing names of all the number columns
local function numberColumnSeq()
   return 
      {'CENSUS.TRACT',
       'NUMBER.OF.BUILDINGS',
       'PROPERTY.ZIPCODE',
       'TOTAL.VALUE.CALCULATED',
       'LAND.VALUE.CALCULATED',
       'IMPROVEMENT.VALUE.CALCULATED',
       'TAX.YEAR',
       'LAND.SQUARE.FOOTAGE',
       'UNIVERSAL.BUILDING.SQUARE.FEET',
       'LIVING.SQUARE.FEET',
       'YEAR.BUILT',
       'EFFECTIVE.YEAR.BUILT',
       'BEDROOMS',
       'TOTAL.ROOMS',
       'TOTAL.BATHS.CALCULATED',
       'FIREPLACE.NUMBER',
       'PARKING.SPACES',
       'UNITS.NUMBER',
       'parcel.file.number',
       'parcel.record.number',
       'apn.recoded'
      }
end

-- return sequence containing names of all the factor columns
local function factorColumnSeq()
   return
      {'ZONING',
       'VIEW',
       'LOCATION.INFLUENCE.CODE',
       --'PROPERTY.CITY',  
       'AIR.CONDITIONING.CODE',
       'CONDITION.CODE',
       'CONSTRUCTION.TYPE.CODE',
       'EXTERIOR.WALLS.CODE',
       'FIREPLACE.INDICATOR.FLAG',
       'FIREPLACE.TYPE.CODE',
       'FOUNDATION.CODE',
       'FLOOR.CODE',
       'FRAME.CODE',
       'GARAGE.CODE',
       'HEATING.CODE',
       'PARKING.TYPE.CODE',
       'POOL.FLAG',
       'POOL.CODE',
       'QUALITY.CODE',
       'ROOF.COVER.CODE',
       'ROOF.TYPE.CODE',
       'STYLE.CODE',
       'SEWER.CODE',
       'WATER.CODE'
      }
end

-- read geocoded parcels records
-- ARGS
-- pathToFile  : string, path to geocodings file
-- readLimit   : integer; if >0, number of geocoding records that are read
-- RETURNS
-- NamedMatrix :  with all rows and all columns
local function readParcelsGeocodes(pathToFile, readLimit)
   local vp = makeVp(0, 'readParcelsGeocoded')
   vp(1, 'pathToFile', pathToFile)
   vp(1, 'readLimit', readLimit)

   local numberColumns = numberColumnSeq()
   local factorColumns = factorColumnSeq()

   local parcels = NamedMatrix.readCsv{file=pathToFile
                                       ,nRows=readLimit
                                       ,sep=','
                                       ,nanString=''
                                       ,numberColumns=numberColumns
                                       ,factorColumns=factorColumns
                                      }
   vp(1, 'parcels with geocoding', parcels)
   return parcels
end -- function readGeocoding

-- write the output file and echo it to stdout
-- ARGS
-- pathToOutput : string, path to output file
-- isMissing    : table, key=column name, value = # of times code was ''
-- isPresent    : table, key=column name, value = # of time code was present
-- RETURNS:
-- count        : number, count of data record written
local function writeOutput(pathToOutput, isMissing, isPresent)
-- write output file
-- separator ,
-- nanString ''
-- don't quote strings
   local vp = makeVp(0, 'writeOutput')
   vp(1, 'writing output file', pathToOutput)
   vp(1, 'isMissing', isMissing)
   vp(1, 'isPresent', isPresent)
   
   local f, err = io.open(pathToOutput, "w")
   if f == nil then
      vp(0, 'ERROR in opening output file: ' .. err)
      exit(1)
   end

   -- write the header
   vp(0, 'records written to output file')
   local header = 'code,nMissing,nPresent\n'
   vp(0, header)
   f:write(header)

   -- write the records
   local nDataRecords = 0
   for k, nMissing in pairs(isMissing) do
      local nPresent = isPresent[k]
      if nPresent == nil then
         vp(0, 'k', k)
         vp(0, 'isMissing')
         vp(0, 'isPresent')
         error('nPresent is nil')
      end
      local data = string.format('%s,%d,%d\n',
                                 k, nMissing, nPresent)
      nDataRecords = nDataRecords + 1
      vp(0, data)
      f:write(data)
   end

   vp(1, 'nDataRecords', nDataRecords)
   return nDataRecords
end

-- how often a code is missing and present
-- ARGS
-- parcels  : NamedMatrix
-- codeName : string, name of column to examine. It must be a level
-- RETURNS
-- nMissing : number, number of times the code column value is NaN
-- nPresent : number, number of times the code column value is non NaN
local function missingPresent(parcels, codeName)
   local vp = makeVp(0, 'missingPresent')
   vp(1, 'parcels', parcels)
   vp(1, 'codeName', codeName)

   local cIndex = parcels:columnIndex(codeName)
   local nMissing = 0
   local nPresent = 0
   for i = 1, parcels.t:size(1) do
      if isnan(parcels.t[i][cIndex]) then
         nMissing = nMissing + 1
      else
         nPresent = nPresent + 1
      end
   end

   vp(1, 'nMissing', nMissing, 'nPresent', nPresent)
   return nMissing, nPresent
end


--------------------------------------------------------------------------------
-- MAIN starts here
--------------------------------------------------------------------------------

local vp = makeVp(2, 'parcels-missing-codes-analysis MAIN')

-- define input and output files
local outputDir = '../data/v6/output/'
local pathToInput = outputDir .. 'parcels-sfr-geocoded.csv'
local pathToOutput = outputDir .. 'parcels-missing-codes-analysis.csv'
local pathToLogfile = outputDir .. 'parcels-missing-codes-analysis.log'

-- say how many records to read
-- -1 ==> all
local inputReadLimit = -1
--local inputReadLimit = 1000

-- arg is sequence containing the command line arguments
startLogging(pathToLogfile, arg)  -- now print() also writes to log file

-- log the parameters
vp(0, 'outputDir', outputDir)
vp(0, 'pathToInput', pathToInput)
vp(0, 'pathToOutput', pathToOutput)
vp(0, 'pathToLogfile', pathToLogfile)
vp(0, 'inputReadLimit', inputReadLimit)

-- read and merge the data, recoding apns
vp(1, 'reading parcels file')
local parcels = readParcelsGeocodes(pathToInput, inputReadLimit)
local used = memoryUsed()  -- collect garbage also
vp(1, string.format('memory used after reading parcels = %d x 10^6 bytes',
                    used / (10^6)))
--vp(2, 'parcels', parcels)

-- accumulate number of times each code is missing and present
local isMissing = {}
local isPresent = {}
for _, factorColumnName in ipairs(factorColumnSeq()) do
   local missing, present = missingPresent(parcels, factorColumnName)
   isMissing[factorColumnName] = missing
   isPresent[factorColumnName] = present
end

local nDataRecords = writeOutput(pathToOutput, isMissing, isPresent)
vp(1, 'wrote output file', pathToOutput)
vp(1, 'number of data records written', nDataRecords)



if inputReadLimit ~= -1 then
   print('DOES NOT CONTAIN ALL THE INPUT. RERUN FOR PRODUCTION')
end

print('ok')

