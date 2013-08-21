require 'makeVp'
require 'validateAttributes'

-- split 4 NamedMatrix's out of one NamedMatrix
-- ARG
-- nm                : NamedMatrix
-- targetFeatureName : string
-- RETURNS 1 table with four components
-- t.attributes : NamedMatrix with n numberic columns (one per feature)
-- t.locations  : NamedMatrix with 3 columns (G LATITUDE, G LONGITUDE, YEAR.BUILT)
-- t.targets    : NamedMatrix with 1 column
-- t.apns       : NamedMatrix with 1 column
function attributesLocationsTargetsApns(nm, targetFeatureName)
   local vp = makeVp(0, 'attributesLocationsTargetsApns')
   vp(1, 'nm', nm, 'targetFeatureName', targetFeatureName)
   validateAttributes(nm, 'NamedMatrix')
   validateAttributes(targetFeatureName, 'string')

   -- NOTE: attributes include the locations
   local attributes = nm:onlyColumns({'G LATITUDE',
                                      'G LONGITUDE',
                                      'YEAR.BUILT',
                                      'PARKING.SPACES',
                                      'UNIVERSAL.BUILDING.SQUARE.FEET',
                                      'TOTAL.BATHS.CALCULATED',
                                      'LAND.SQUARE.FOOTAGE',
                                      'BEDROOMS'})

   local locations = nm:onlyColumns({'G LATITUDE', 'G LONGITUDE', 'YEAR.BUILT'})
   local targets = nm:onlyColumns({targetFeatureName})
   local apns = nm:onlyColumns({'apn.recoded'})
   vp(1, 
      '\nattributes', attributes, 
      '\nlocations', locations, 
      '\ntargets', targets, 
      '\napns', apns)

   local table = {attributes = attributes,
                  locations = locations,
                  targets = targets,
                  apns = apns}
   vp(1, 'table', table)
   return table
end

