-- distancesSurface.lua

require 'head' 
require 'makeVp'
require 'metersPerLatitudeDegree'
require 'metersPerLongitudeDegree'
require 'validateAttributes'

-- determine surface distances on earth from a query point to a other points
-- ARGS
-- query     : 1D Tensor of size m
-- others    : 2D Tensor of size n x m
-- mPerYear  : number, number of meters corresponding to one year
-- names     : table with fields .latitude, .longitude, .year
--             the column number is query and others of the corresponding values
-- RETURNS
-- distances : 1D Tensor of distances in equivalent meters
function distancesSurface(query, others, mPerYear, names)
   local vp, verboseLevel = makeVp(0, 'distancesSurface')
   local v = verboseLevel > 0
   if v then
      vp(1, 'query', query)
      vp(1, 'others size', others:size())
      vp(1, 'others head', head(others))
      vp(1, 'mPerYear', mPerYear)
      vp(1, 'names', names)
   end

   -- validate args
   validateAttributes(query, 'Tensor', '1d')
   validateAttributes(others, 'Tensor', '2d')
   validateAttributes(mPerYear, 'number', '>=', 0)
   validateAttributes(names, 'table')
   validateAttributes(names.latitude, 'number', '>=', 1)
   validateAttributes(names.longitude, 'number', '>=', 1)
   validateAttributes(names.year, 'number', '>=', 1)

   -- set column numbers
   local cLatitude = names.latitude
   local cLongitude = names.longitude
   local cYear = names.year
   if v then
       vp(2, 'cLatitude', cLatitude)
       vp(2, 'cLongitude', cLongitude)
       vp(2, 'cYear', cYear)
   end


   -- view query as 2D by replicating the row n times
   -- NOTE: since the queryLocation might have been formed with borrowed
   -- storage, it is necessary to clone it first. This bug was very hard
   -- to find.
   local n = others:size(1)
   local m = others:size(2)
   assert(m == query:size(1))

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
