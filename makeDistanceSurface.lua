-- makeDistanceSurface.lua
-- make cacheing distance function on Earth's surface

-- TODO: return indices and distances, not just distances
-- TODO: cache (say) 256 nearest
-- TODO: return either 256 nearest or number specified

require 'ifelse'
require 'makeVp'

function makeDistanceSurface(t)
   local arg = {}
   arg.mPerYear = t.mPerYear or error('must supply meters per year')
   arg.filename = t.filename
   arg.latitudes = t.latitudes or error('missing latitudes')
   arg.longitudes = t.longitudes or error('missing longitudes')
   arg.years = t.years or error('missing years')
   -- store everything to be cached in arg table
   arg.n = arg.latitudes:size(1)
   arg.cache = {}

   arg.verbose = 0 

   local vp = makeVp(arg.verbose)

   -- check args
   assert(arg.latitudes:nDimension() == 1)
   assert(arg.longitudes:nDimension() == 1)
   assert(arg.years:nDimension() == 1)
   assert(arg.n == arg.longitudes:size(1))
   assert(arg.n == arg.years:size(1))

   -- geometry of the Earth using WGS 84 model
   -- see Wikipedia at Latitude
   local param = {}
   param.a = 6378137            -- radius of Earth at equator in km
   param.e2 = 0.00669437999014  -- square of Earth's eccentricity

   local function equal1DTensors(a, b)
      if a:size(1) ~= b:size(1) then
         return false
      end
      local compare = torch.eq(a, b)
      return torch.sum(compare) == a:size(1)
   end

   -- deserialize if serialization file exists
   if arg.filename then
      -- deseriealize cache
      if paths.filep(arg.filename) then
         newarg = torch.load(arg.filename, 'binary')
         vp(1, 'deserialized newarg', newarg)
         -- check that no key parameters have changes
         assert(newarg.mPerYear == arg.mPerYear)
         assert(equal1DTensors(newarg.latitudes, arg.latitudes))
         assert(equal1DTensors(newarg.longitudes, arg.longitudes))
         assert(equal1DTensors(newarg.years, arg.years))
         arg = newarg
      else
         vp(1, 'serialization file does not exist')
      end
   end

   local function writeCache()
      torch.save(arg.filename, arg, 'binary')
   end

   -- See the Wikipedia article for these function

   -- return meters per degree of latitude at specified latitude phi
   local numerator = math.pi * param.a * (1 - param.e2)
   local function mPerLatitudeDegree(phi) 
     local sin = math.sin(math.rad(phi))
     local denominator = 180 * math.pow(1 - param.e2  * sin * sin,
                                        1.5)
     return numerator / denominator
   end

   -- return meters per degree of longitude at specified latitude phi
   local function mPerLongitudeDegree(phi)
      local x = math.rad(phi)
      local numerator = math.pi * param.a * math.cos(x)
      local sin = math.sin(x)
      local denominator = 180 * math.pow(1 - param.e2  * sin * sin,
                                         0.5)
      return numerator / denominator
   end

   -- unit test using results in the Wikipedia article
   local function check(expected, actual)
      assert(math.abs(expected - actual) < 1,
             'expected=' .. expected .. ' actual=' .. actual)
   end
   check(110574, mPerLatitudeDegree(0))
   check(111320, mPerLongitudeDegree(0))
   check(110852, mPerLatitudeDegree(30))
   check(96486, mPerLongitudeDegree(30))
   check(111694, mPerLatitudeDegree(90))
   check(0, mPerLongitudeDegree(90))

   if arg.verbose >= 3 then
      -- print info useful for unit testing
      local phi = 29.5
      vp(3, 'phi', phi)
      vp(3, 'm per latitude degree', mPerLatitudeDegree(phi))
      vp(3, 'm per longitude degree', mPerLongitudeDegree(phi))
      phi = 30.0
      vp(3, 'phi', phi)
      vp(3, 'm per latitude degree', mPerLatitudeDegree(phi))
      vp(3, 'm per longitude degree', mPerLongitudeDegree(phi))
   end

   local function cacheKey(query)
      -- a key cannot be a computed table
      -- hence convert the query (a table) to a string
      return string.format('%f*%f*%d',
                           query.latitude, query.longitude, query.year)
   end

   -- return Tensor of distances and boolean (was cache used)
   local function distances(t)
      local query = {}
      query.latitude = t.latitude or error('missing latitude')
      query.longitude = t.longitude or error('missing longitude')
      query.year = t.year or error('missing year')
      query.verbose = 0
      
      local vp = makeVp(query.verbose)

      vp(1, 'query', query)
      vp(2, 'arg.cache', arg.cache)

      -- check if in cache
      local key = cacheKey(query)
      local cacheValue = arg.cache[key]
      vp(2, 'key', key)
      vp(2, 'cacheValue', cacheValue)
      if cacheValue then
         vp(1, 'distances from cache', cacheValue)
         return cacheValue, true -- used cache
      end

      -- not in cache, so compute all distances
      -- see Wikipedia at "Latitude" for these formulae
      local avgLatitudes = (arg.latitudes + query.latitude) / 2
      vp(3, 'avgLatitudes', avgLatitudes)

      local mPerDegreeLatitude = 
         avgLatitudes:clone():apply(mPerLatitudeDegree)
      local mPerDegreeLongitude = 
         avgLatitudes:clone():apply(mPerLongitudeDegree)
      vp(3, 'mPerDegreeLatitude', mPerDegreeLatitude)
      vp(3, 'mPerDegreeLongitude', mPerDegreeLongitude)

      local deltaLatitudes = arg.latitudes - query.latitude
      local deltaLongitudes = arg.longitudes - query.longitude
      local deltaYears = arg.years - query.year
      vp(3, 'deltaLatitudes', deltaLatitudes)
      vp(3, 'deltaLongitudes', deltaLongitudes)
      vp(3, 'deltaYears', deltaYears)

      local d1 = torch.cmul(deltaLatitudes, mPerDegreeLatitude)
      local d2 = torch.cmul(deltaLongitudes, mPerDegreeLongitude)
      local d3 = deltaYears * arg.mPerYear
      vp(3, 'd1', d1)
      vp(3, 'd2', d2)
      vp(3, 'd3', d3)

      local d = torch.cmul(d1, d1) + torch.cmul(d2, d2) + torch.cmul(d3, d3)
      d:apply(math.sqrt)

      -- store in cache
      arg.cache[cacheKey(query)] = d
      
      vp(1, 'distances', d)
      return d, false  -- no cache was used
   end

   return distances, writeCache
end
      
      

