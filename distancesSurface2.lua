-- distancesSurface2.lua

require 'head' 
require 'makeVp'
require 'metersPerLatitudeDegree'
require 'metersPerLongitudeDegree'
require 'torch'

-- determine surface distances on earth from a query point to a other points
-- ARGS
-- query     : table with fields .latitude .longitude .year, each a number
-- others    : table with fields .latitude .longitude .year, each a 1D Tensor of size n
-- mPerYear  : number, number of meters corresponding to one year
-- RETURNS
-- distances : 1D Tensor of distances in equivalent meters
function distancesSurface2(query, others, mPerYear)
   local vp, verboseLevel = makeVp(0, 'distancesSurface')
   local v = verboseLevel > 0
   if v then
      vp(1, 'query', query, 'othes', others, 'mPerYear', mPerYear)
   end

   -- create 1D tensor for each query element
   local n = others.latitude:size(1)
   local function make1DTensor(value)
      return torch.Tensor(n):fill(value)
   end

   local queryTensor1d = {
      latitude = make1DTensor(query.latitude),
      longitude = make1DTensor(query.longitude),
      year = make1DTensor(query.year),
   }

   -- surface distances depend on the latitude on the surface
   -- use the average latitude
   local avgLatitude = (others.latitude + query.latitude) / 2
   
   -- find distances in meters along each of the 3 dimensions
   local dLatitudeMeters = torch.cmul(others.latitude - query.latitude, 
                                      metersPerLatitudeDegree(avgLatitude))
   local dLongitudeMeters = torch.cmul(others.longitude - query.longitude,
                                       metersPerLongitudeDegree(avgLatitude))
   local dYearsMeters = (others.year - query.year) * mPerYear

   local distances = (torch.cmul(dLatitudeMeters, dLatitudeMeters) +
                      torch.cmul(dLongitudeMeters, dLongitudeMeters) +
                      torch.cmul(dYearsMeters, dYearsMeters)) : sqrt()

   if v then
      vp(1, 'distances', distance)
   end

   return distances
end
--[[ OLD CODE
   -- new version without 2D views
   local avgLatitude = (others:select(2, cLatitude) + query[cLatitude]) / 2
   if v then
       vp(2, 'others head', head(others))
       vp(2, 'query', query)
       vp(2, 'avgLatitude head', head(avgLatitude))
   end

   local dLatitudeMeters = 
      torch.cmul(others:select(2, cLatitude) - query[cLatitude],
                 metersPerLatitudeDegree(avgLatitude))
   local dLongitudeMeters =
      torch.cmul(others:select(2, cLongitude) - query[cLongitude],
                 metersPerLongitudeDegree(avgLatitude))
   local dYearMeters =
      (others:select(2, cYear) - query[cYear]) * mPerYear
   if v then 
       vp(2, 'dLatitudeMeters head', head(dLatitudeMeters)) 
       vp(2, 'dLongitudeMeters head', head(dLongitudeMeters))
       vp(2, 'dYearMeters size', dYearMeters:size())
       vp(2, 'dYearMeters head', head(dYearMeters))
   end
   local distances = (torch.cmul(dLatitudeMeters, dLatitudeMeters) +
                      torch.cmul(dLongitudeMeters, dLongitudeMeters) +
                      torch.cmul(dYearMeters, dYearMeters)):sqrt()
   if v then vp(2, 'distances head', head(distances)) end

   return distances -- in equivalent meters
end
--]]
