require 'makeVp'
require 'NamedMatrix'
require 'Timer'

-- read the file parcels-sfr-geocoded.csv returning a NamedMatrix with the features
-- needed to impute the specified code
-- ARGS:
-- pathToParcels     : string, location of input file
-- readLimit         : number, possible limit on number of records to read
-- targetFeatureName : string, column name for target feature
-- RETURNS
-- data              : NamedMatrix
function readParcelsSfrGeocoded(pathToParcels, readLimit, targetFeatureName)
   local vp = makeVp(0, 'readParcels')
   vp(1, 
      'pathToParcels', pathToParcels, 
      'readLimit', readLimit,
      'targetFeatureName', targetFeatureName)

   -- validate args
   validateAttributes(pathToParcels, 'string')
   validateAttributes(readLimit, 'number', '>=', -1)
   validateAttributes(targetFeatureName, 'string')

   -- read parcels
   vp(2, 'reading from csv file', pathToParcels)
   local numberColumns = {-- description
                          'LAND.SQUARE.FOOTAGE', 'TOTAL.BATHS.CALCULATED',
                          'BEDROOMS', 
                          'PARKING.SPACES', 'UNIVERSAL.BUILDING.SQUARE.FEET',
                          -- location
                          'YEAR.BUILT', 'G LATITUDE', 'G LONGITUDE',
                          -- identification
                          'apn.recoded'}
   
   local factorColumns = {targetFeatureName}
   
   local timer = Timer()
   parcels = NamedMatrix.readCsv{file=pathToParcels
                                 ,nRows=readLimit
                                 ,numberColumns=numberColumns
                                 ,factorColumns=factorColumns
                                 ,nanString=''
                                }
   vp(2, 'wall clock secs to read parcels file', timer:wallclock())

   vp(1, 'parcels', parcels)
   return parcels
end
