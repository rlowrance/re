-- parcels-sfr-recoded.lua
-- main program to create file OUTPUT/parcels-sfr-recoded.lua
-- INPUT FILES
-- OUTPUT/parcels-sfr.csv : all single family residential (SFR) parcels
-- OUTPUT FILES
-- OUTPUT/parcels-sfr-recoded.csv : csv file containing SFR parcels with
--                                  a recoded APN.
--
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

-- replace APN.FORMATTED and APN.UNFORMATTED with apn.recoded
-- RETURN: mutated data frame
local function createApnRecodedFeature(parcels)
   -- NOTE: This implementation creates potentially large sequences, a
   -- potential problem if the LuaJIT is running.
   -- NOTE: Avoid the sequences seems impossible, since strings are needed
   -- to decode the APN.FORMATTED field
   local vp = makeVp(0, 'createApnRecodedFeature')
   
   local function levels(colName)
      -- return seq of strings
      local seq = {}
      local colIndex = parcels:columnIndex(colName)
      for rowIndex = 1, parcels.t:size(1) do
         table.insert(seq, parcels:getLevel(rowIndex, colIndex))
      end
      if seq and bytesIn(seq) > 1024 * 1024 * 1024 then
         error('large sequence')
      end
      return seq
   end

   local apnsRecoded = 
      bestApns{formattedApns = levels('APN.FORMATTED')
               ,unformattedApns = levels('APN.UNFORMATTED')
               ,na=0/0
              }
   local bestTensor = torch.Tensor{apnsRecoded}:t()

   local recoded = NamedMatrix{tensor=bestTensor,
                               names={'apn.recoded'},
                               levels={}}
   parcels = parcels:dropColumn('APN.FORMATTED'):dropColumn('APN.UNFORMATTED')
   parcels = NamedMatrix.concatenateHorizontally(parcels, recoded)
      
   vp(1, 'parcels', parcels)
   return parcels
end -- function createApnRecodedFeature

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
       'parcel.record.number'
      }

   local factorColumns =
      {'APN.UNFORMATTED',
       'APN.FORMATTED',
       'ZONING',
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
                                      ,nanString='NA'
                                     }

  vp(1, 'parcels', parcels)
  return parcels
end -- function readParcels

--------------------------------------------------------------------------------
-- MAIN starts here
--------------------------------------------------------------------------------

local vp = makeVp(2, 'parcels-sfr-recoded MAIN')

-- define input and output files
local outputDir = '../data/v6/output/'
local pathToParcels = outputDir .. 'parcels-sfr.csv'
local pathToLogfile = outputDir .. 'parcels-sfr-recoded.log'
local pathToOutputFile = outputDir .. 'parcels-sfr-recoded.csv'

-- say how many records to read
-- -1 ==> all
local parcelsReadLimit = -1

-- arg is sequence containing the command line arguments
startLogging(pathToLogfile, arg)  -- now print() also writes to log file

-- log the parameters
vp(0, 'outputDir', outputDir)
vp(0, 'pathToGeocodings', pathToGeocodings)
vp(0, 'pathToParcels', pathToParcels)
vp(0, 'pathToLogfile', pathToLogfile)
vp(0, 'pathToOutputFile', pathToOutputFile)
vp(0, 'parcelsReadLimit', parcelsReadLimit)

-- read and merge the data, recoding apns
vp(1, 'reading parcels file')
local parcels = readParcels(pathToParcels, parcelsReadLimit)
local used = memoryUsed()  -- collect garbage also
vp(1, string.format('memory used after reading parcels = %d x 10^6 bytes',
                    used / (10^6)))
--vp(2, 'parcels', parcels)

-- recode bizarre APNs
vp(1, 'recoding APNs')
local parcels = createApnRecodedFeature(parcels)
vp(2, 'parcels with recoded APNS', parcels)

-- write output file
-- separator ,
-- nanString ''
-- don't quote strings
vp(1, 'writing merged file')
parcels:writeCsv{file=pathToOutputFile
                ,colNames=true           -- write header with column names
                ,sep=','                 -- separate fields with ,
                ,nanString=''            -- replace NaN values with empty str
                ,quote=false             -- do not quote strings
               }
vp(1, 'wrote file ' .. pathToOutputFile)

if parcelsReadLimit ~= -1 then
   print('DOES NOT CONTAIN ALL THE PARCELS. RERUN FOR PRODUCTION')
end

print('ok')

