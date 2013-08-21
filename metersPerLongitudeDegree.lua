-- metersPerLongitudeDegree.lua

require 'earth'
require 'makeVp'

-- determine number of meters in one degree of longitude on Earth's surface at
-- a specified latitude using the WGS 84 model
-- ARGS:
-- latitude : Tensor or scalar, degrees of latitude
-- RETURNS
-- meters   : obj of same type as latitude
--            meters per degree at the specified latitude
-- REF: Wikipedia at Longiude heading "length of a degree of latitude"
function metersPerLongitudeDegree(latitude)
   local vp, verbose = makeVp(0, 'metersPerLongitudeDegree')
   local d = verbose > 0
   if d then vp(1, 'latitude', latitude) end

   -- handle argument types
   if type(latitude) == 'number' then
      local input = torch.Tensor(1, 1):fill(latitude)
      local result = metersPerLongitudeDegree(input)
      if d then vp(1, 'result', result) end
      return result[1][1]
   end

   assert(0 <= latitude:min())
   assert(latitude:max() <= 90)

   local function toCosRad(x)
      return math.cos(math.rad(x))
   end

   local numerator = latitude:clone():apply(toCosRad) * earth.a * math.pi

   local function toSinRad(x)
      return math.sin(math.rad(x))
   end

   local sin = latitude:clone():apply(toSinRad)
   local one = latitude:clone():fill(1)
   local denominator = torch.pow(one - torch.cmul(sin, sin) * earth.e2,
                                 0.5) * 180

   return torch.cdiv(numerator, denominator)

end

