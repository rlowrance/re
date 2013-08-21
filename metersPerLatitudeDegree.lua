-- metersPerLatitudeDegree.lua

require 'earth'
require 'makeVp'

-- determine number of meters in one degree of latitude on Earth's surface
-- using the WGS 84 model
-- ARGS:
-- latitude : Tensor or scalar, degrees of latitude
-- RETURNS
-- meters   : obj of same time and size as latitude
--            meters per degree at the specified latitude
-- REF: Wikipedia at Latitude heading "length of a degree of latitude"
function metersPerLatitudeDegree(latitude)
   local vp, verbose = makeVp(0, 'metersPerLatitudeDegree')
   local d = verbose > 0
   if d then
      vp(1, 'latitude', latitude)
   end

   -- handle argument types
   if type(latitude) == 'number' then
      local tensor = torch.Tensor(1,1):fill(latitude)
      local result = metersPerLatitudeDegree(tensor)
      if d then vp(1, 'result', result) end
      return result[1][1]
   end

   -- assure all values in [0,90]
   assert(latitude:max() <= 90,
          'at least one latitude exceeds 90 degrees')
   assert(latitude:min() >= 0,
          'at least one latitude is negative')

   local numerator = math.pi * earth.a * (1 - earth.e2)
   local numTensor = latitude:clone():fill(numerator)  -- works on any size

   local function toSinRad(x)
      return math.sin(math.rad(x))
   end

   local sin = latitude:clone():apply(toSinRad)
   local one = latitude:clone():fill(1)
   local denominator = torch.pow(one - torch.cmul(sin, sin) * earth.e2,
                                 1.5) * 180

   return torch.cdiv(numTensor, denominator)
end

