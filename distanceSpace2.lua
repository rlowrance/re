-- distanceSpace2.lua

require 'makeVp'
require 'metersPerLatitudeDegree'
require 'metersPerLongitudeDegree'
require 'pp'

-- return squared time distances from query to every other sample (in units years^2)
-- ARGS:
-- latitudes      : 1D Tensor of latitudes in degrees; size n
-- longitudes     : 1D Tensor of longitudes in degrees; size n
-- queryLatitude  : number of degree latitude
-- queryLongitude : number of degrees of longitude
-- RETURNS
-- distances2     : 1D Tensor of size n
function distanceSpace2(latitudes, longitudes, queryLatitude, queryLongitude)
   local n = latitudes:size(1)

   -- build vectors containing the query point
   local queryLatitude1 = torch.Tensor{queryLatitude}
   local queryLatitude = torch.Tensor(queryLatitude1:storage(), 1, n, 0)
   local queryLongitude1 = torch.Tensor{queryLongitude}
   local queryLongitude = torch.Tensor(queryLongitude1:storage(), 1, n, 0)

   -- distances depend on the latitude
   -- use the average latitude
   local avgLatitudes = (latitudes + queryLatitude) / 2

   -- distances in meters in each dimension
   local dLatitudes = torch.cmul(latitudes - queryLatitude, metersPerLatitudeDegree(avgLatitudes))
   local dLongitudes = torch.cmul(longitudes - queryLongitude, metersPerLongitudeDegree(avgLatitudes))

   local distances2 = torch.cmul(dLatitudes, dLatitudes) + torch.cmul(dLongitudes, dLongitudes)
   return distances2
end
