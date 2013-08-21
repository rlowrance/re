-- parcels-sfr-geocoding-valid.lua
-- main program to create file OUTPUT/geocoding-valid.csv
-- INPUT FILES
-- RAW/geocoding.tsv      :  all geocodings
-- OUTPUT FILES
-- OUTPUT/geocoding-valid.csv: CSV file containing just the geocoding records
--                             for which both latitude and longitude are 
--                             provided
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

-- read all of the 2.3 million geocodings and return the valid ones in a 
-- NamedMatrix. The valid ones have both a latitude and longitude value.
-- ARGS
-- pathToGeocoding : string, path to geocodings file
-- readLimit       : integer; if >0, number of geocoding records that are read
-- RETURNS
-- NamedMatrix     :  with selected rows and all columns
local function readGeocoding(pathToGeocoding, readLimit)
   local vp = makeVp(0, 'readGeocoding')
   vp(1, 'pathToGeocoding', pathToGeocoding)
   vp(1, 'readLimit', readLimit)

   local numberColumns = {'G APN', 'G LATITUDE', 'G LONGITUDE'}
   local geocoding = NamedMatrix.readCsv{file=pathToGeocoding
                                         ,nRows=readLimit
                                         ,sep='\t'
                                         ,numberColumns=numberColumns
                                         }
   vp(2, 'read geocoding into NamedMatrix')
   vp(2, 
      'geocoding.t:size()', geocoding.t:size(),
      'geocoding.names', geocoding.names,
      'geocoding.levels', geocoding.level)
   assert(not hasNaN(geocoding.t))

   -- verify that not latitudes or longitudes are 0
   local indexLatitude = geocoding:columnIndex('G LATITUDE')
   local indexLongitude = geocoding:columnIndex('G LONGITUDE')

   local function zeroFound(i)
      local zero = false
      if geocoding.t[i][indexLatitude] == 0 then
         vp(3, 'geocoding[' .. tostring(i) .. ']', geocoding.t[i])
         return true
      end
      if geocoding.t[i][indexLongitude] == 0 then
         vp(3, 'geocoding[' .. tostring(i) .. ']', geocoding.t[i])
         return true
      end
      return false
   end

   local hasZero, hasNoZero = geocoding:splitRows(zeroFound)
   vp(2, 'hasZero', hasZero)
   vp(2, 'hasNoZero', hasNoZero)

   return hasNoZero
end -- function readGeocoding


--------------------------------------------------------------------------------
-- MAIN starts here
--------------------------------------------------------------------------------

local vp = makeVp(2, 'geocoding-valid MAIN')

-- define input and output files
local outputDir = '../data/v6/output/'
local pathToGeocoding = '../data/raw/geocoding.tsv'
local pathToGeocodingValid = outputDir .. 'geocoding-valid.csv'
local pathToLogfile = outputDir .. 'geocoding-valid.log'

-- say how many records to read
-- -1 ==> all
local geocodingReadLimit = -1

-- arg is sequence containing the command line arguments
startLogging(pathToLogfile, arg)  -- now print() also writes to log file
vp(0, 'outputDir', outputDir)
vp(0, 'pathToGeocoding', pathToGeocoding)
vp(0, 'pathToGeocodingValid', pathToGeocodingValid)
vp(0, 'geocodingsReadLimit', geocodingsReadLimit)

-- read geocoding records
vp(1, 'reading geocoding file')
local geocoding = readGeocoding(pathToGeocoding, geocodingReadLimit)
local used = memoryUsed()
vp(1, string.format('memory used after reading geocoding = %d x 10^6 bytes',
                    used / (10^6)))


-- write output file
-- separator ,
-- nanString ''
-- don't quote strings
vp(1, 'writing output file')
geocoding:writeCsv{file=pathToGeocodingValid
                   ,colNames=true           -- write header with column names
                   ,sep=','                 -- separate fields with ,
                   ,nanString=''            -- replace NaN values with empty str
                   ,quote=false             -- do not quote strings
               }
vp(1, 'wrote file ' .. pathToGeocodingValid)

if geocodingReadLimit ~= -1 then
   print('DOES NOT CONTAIN ALL THE GEOCODES. RERUN FOR PRODUCTION')
end

print('ok')

