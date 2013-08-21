-- metersPerLongitudeDegree_test.lua

require 'assertEq'
require 'makeVp'
require 'metersPerLongitudeDegree'

verbose = 0
vp = makeVp(verbose)

tolerance = 1
function check(a, b)
   vp(2, 'a', a, 'b', b)
   assert(math.abs(a - b) < tolerance)
end

-- examples are from the Wikipedia article
-- test scalar
check(111320, metersPerLongitudeDegree(0))
check(107551, metersPerLongitudeDegree(15))
check( 96486, metersPerLongitudeDegree(30))
check( 78847, metersPerLongitudeDegree(45))
check( 55800, metersPerLongitudeDegree(60))
check( 28902, metersPerLongitudeDegree(75))
check(     0, metersPerLongitudeDegree(90))

-- test 2D Tensor
local longitudes = torch.Tensor{{0, 15, 30},
                                {45, 60, 75},
                                {90, 90, 90}}
local r = metersPerLongitudeDegree(longitudes)
assertEq(torch.Tensor{{111320, 107551, 96486},
                      {78847, 55800, 28902},
                      {0, 0, 0}},
         r,
         1)

-- test 1D Tensor
local longitudes = torch.Tensor{0, 15, 30, 45, 60, 75, 90}
local r = metersPerLongitudeDegree(longitudes)
assertEq(torch.Tensor{111320, 107551, 96486, 78847, 55800, 28902, 0 },
         r,
         1)


print('ok metersPerLongitudeDegree')