-- read samples and columns from parcels-sfr-geocoded.csv needed for imputation

require 'NamedMatrix'
require 'pp'

-- ARGS:
-- what            : string in {'version', 'object'}
-- path            : string
-- args            : table of arguments containing
--                   .readlimit     : if > 0, number of samples to read
-- RETURNS:
-- table or number : if number, the version number
--                   if table, results which are in these fields
--                  .nm the named matrix
--                  .numberColumns : sequence of number column names
--                  .factorColumn  : sequence of factor column names
function readParcelsForImputation(what, path, args)
   if what == 'version' then
      return 1
   end

   assert(what == 'object')
   assert(type(path) == 'string')
   assert(type(args) == 'table')
   assert(args.readlimit ~= nil)
   local readlimit = args.readlimit

   local numberColumnNames = {
      'G LATITUDE',     -- location
      'G LONGITUDE',
      'YEAR.BUILT',
      'BEDROOMS',       -- description
      'LAND.SQUARE.FOOTAGE',
      'PARKING.SPACES',
      'TOTAL.BATHS.CALCULATED',
      'UNIVERSAL.BUILDING.SQUARE.FEET',
   }

   local factorColumnNames = {
      'ZONING',  -- fields to impute (from file transactions-subset1-to-impute.csv)
      'VIEW',
      'LOCATION.INFLUENCE.CODE',
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
      'POOL.CODE',
      'QUALITY.CODE',
      'ROOF.COVER.CODE',
      'ROOF.TYPE.CODE',
      'STYLE.CODE',
      'WATER.CODE',
   }

   assert(path == '../data/v6/output/parcels-sfr-geocoded.csv', path)
   local nm = NamedMatrix.readCsv{
      file = path,
      sep = ',',
      nanString = '',
      nRows = readlimit,
      numberColumns = numberColumnNames, 
      factorColumns = factorColumnNames,
      skip = 0,
   }

   return {
      nm = nm, 
      factorColumnNames = factorColumnNames,
      numberColumnNames = numberColumnNames,
   }
end



