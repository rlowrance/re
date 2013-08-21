-- parcels-sfr-geocoded.lua
-- main program to create file OUTPUT/parcels-sfr-geocoded.lua
-- INPUT FILES
-- OUTPUT/parcels-sfr-recoded.csv : all single family residential (SFR) parcels
--                                  with bizarre APNs recoded
-- RAW/geocoding-valid.tsv        : all geocodings
-- OUTPUT FILES
-- OUTPUT/parcels-sfr-geocoded.csv : csv file containing SFR parcels that
--                                   have valid geocodings. The APNS in the 
--                                   parcels file are recoded.
--
-- COMMAND LINE PARAMETERS: NONE

require 'bestApns'
require 'hasNaN'
require 'isnan'
require 'makeVp'
require 'memoryUsed'
require 'NamedMatrix'
require 'startLogging'

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------


-- read geocoding records
-- NamedMatrix
-- ARGS
-- pathToGeocodings : string, path to geocodings file
-- readLimit        : integer; if >0, number of geocoding records that are read
-- RETURNS
-- NamedMatrix :  with selected rows and all columns
local function readGeocoding(pathToGeocoding, readLimit)
   local vp = makeVp(1, 'readGeocoding')
   vp(1, 'pathToGeocoding', pathToGeocoding)
   vp(1, 'readLimit', readLimit)

   local numberColumns = {'G APN', 'G LATITUDE', 'G LONGITUDE'}
   local geocoding = NamedMatrix.readCsv{file=pathToGeocoding
                                          ,nRows=readLimit
                                          ,sep=','
                                          ,numberColumns=numberColumns
                                         }
   vp(1, 
      'geocoding.t:size()', geocoding.t:size(),
      'geocoding.names', geocoding.names,
      'geocoding.levels', geocoding.level)
   assert(not hasNaN(geocoding.t))

   return geocoding
end -- function readGeocoding

-- read all of the 1.4 million parcel-sfr.csv records
-- ARGS
-- path      : string, path to the parcels file
-- readLimit : integer: if >= 0, number of parcel data records to read
-- numberColumns: seq of strings: names of columns to read as numbers
-- targetFeatureName: string, name of the target column (read as a string)
-- verbose: integer, verbose level
-- RETURNS: 
-- NamedMatrix : containing all the rows and columns
local function readParcels(pathToParcels, readLimit)
   local vp = makeVp(0, 'readParcels')
   vp(1, 'pathToParcels', pathToParcels, 'readLimit', readLimit)

   local numberColumns = 
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

   local factorColumns =
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
       
  local parcels = NamedMatrix.readCsv{file=pathToParcels
                                      ,nRows=readLimit
                                      ,numberColumns=numberColumns
                                      ,factorColumns=factorColumns
                                      ,nanString=''
                                     }

  vp(1, 'parcels', parcels)
  return parcels
end -- function readParcels


--------------------------------------------------------------------------------
-- MAIN starts here
--------------------------------------------------------------------------------

local vp = makeVp(2, 'parcels-sfr-geocoded MAIN')

-- define input and output files
local outputDir = '../data/v6/output/'
local pathToGeocoding = outputDir .. 'geocoding-valid.csv'
local pathToParcels = outputDir .. 'parcels-sfr-recoded.csv'
local pathToLogfile = outputDir .. 'parcels-sfr-geocoded.log'
local pathToMergedFile = outputDir .. 'parcels-sfr-geocoded.csv'

-- say how many records to read
-- -1 ==> all
local parcelsReadLimit = -1
local geocodingReadLimit = -1

-- arg is sequence containing the command line arguments
startLogging(pathToLogfile, arg)  -- now print() also writes to log file

-- log the parameters
vp(0, 'outputDir', outputDir)
vp(0, 'pathToGeocodings', pathToGeocodings)
vp(0, 'pathToParcels', pathToParcels)
vp(0, 'pathToLogfile', pathToLogfile)
vp(0, 'pathToMergedFile', pathToMergedFile)
vp(0, 'parcelsReadLimit', parcelsReadLimit)
vp(0, 'geocodingReadLimit', geocodingReadLimit)

-- read and merge the data, recoding apns
vp(1, 'reading parcels file')
local parcels = readParcels(pathToParcels, parcelsReadLimit)
local used = memoryUsed()  -- collect garbage also
vp(1, string.format('memory used after reading parcels = %d x 10^6 bytes',
                    used / (10^6)))
--vp(2, 'parcels', parcels)

-- read all the geocoding records
vp(1, 'reading geocodings file')
local geocodings = readGeocoding(pathToGeocoding, geocodingReadLimit)
local used = memoryUsed()
vp(1, string.format('memory used after reading geocoding = %d x 10^6 bytes',
                    used / (10^6)))

-- merge the geocodings and parcels
-- at one point, this statement failed with "torch: out of memory"
merged = NamedMatrix.merge{nmX = parcels
                           ,nmY = geocodings
                           ,byX = 'apn.recoded'
                           ,byY = 'G APN'
                           ,newBy='apn.recoded'
                          }
parcels = nil
geocodings = nil

local used = memoryUsed()
vp(1, string.format('memory used after merging = %d x 10^6 bytes',
                    used / (10^6)))

vp(1, 'merged', merged)


-- write output file
-- separator ,
-- nanString ''
-- don't quote strings
vp(1, 'writing merged file')
merged:writeCsv{file=pathToMergedFile
                ,colNames=true           -- write header with column names
                ,sep=','                 -- separate fields with ,
                ,nanString=''            -- replace NaN values with empty str
                ,quote=false             -- do not quote strings
               }
vp(1, 'wrote file ' .. pathToMergedFile)
vp(1, string.format('the data in the file has %d rows and %d columns',
                    merged.t:size(1), merged.t:size(2)))

if parcelsReadLimit ~= -1 then
   print('DOES NOT CONTAIN ALL THE PARCELS. RERUN FOR PRODUCTION')
end

print('ok')

