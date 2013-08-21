-- readParcelsLocations.lua

require 'makeVp'
require 'NamedMatrix'

-- read just the features used to impute missing codes
-- ARGS:
-- pathToParcels : string
-- readLimit     : number, number of data records to read or -1 for all
-- RETURNS
-- apns          : 1D Tensor of apns
-- locations     : NamedMatrix with YEAR.BUILT, G LATITUDE, G LONGITUDE
function readParcelsLocations(pathToParcels, readLimit)
   local vp = makeVp(2, 'readParcelsLocations')
   vp(1,
      'pathToParcels', pathToParcels,
      'readLimit', readLimit)

   -- validate args
   assert(type(pathToParcels) == 'string')
   assert(type(readLimit) == 'number')

   -- define locations in input CSV file of the returned values
   local apnColumn = {'apn.recoded'}
   local locationColumns = {'YEAR.BUILT', 'G LATITUDE', 'G LONGITUDE'}

   -- define columns to read from the CSV file
   local numberColumns = {}
   numberColumns[1] = apnColumn[1]
   for i = 1, #locationColumns do
      numberColumns[i + 1] = locationColumns[i]
   end
   vp(2, 'locationColumns', locationColumns)
   vp(2, 'numberColumns', numberColumns)

   -- read data
   local data = NamedMatrix.readCsv{file=pathToParcels,
                                    nRows=readLimit,
                                    numberColumns=numberColumns,
                                    nanString=''}

   -- split columns
   vp(2, 'locationColumns', locationColumns)
   local locations = data:onlyColumns(locationColumns)
   local apns = data:onlyColumns(apnColumn)
     
   vp(1,
      'apns', apns,
      'locations', locations)
   return apns, locations
end