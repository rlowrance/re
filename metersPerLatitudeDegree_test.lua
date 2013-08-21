-- metersPerLatitudeDegree_test.lua

require 'assertEq'
require 'makeVp'
require 'metersPerLatitudeDegree'

verbose = 0
vp = makeVp(verbose)

tolerance = 1
function check(a, b)
   assert(math.abs(a - b) < tolerance)
end

-- examples are from the Wikipedia article
check(110574, metersPerLatitudeDegree(0))
check(110649, metersPerLatitudeDegree(15))
check(110852, metersPerLatitudeDegree(30))
check(111132, metersPerLatitudeDegree(45))
check(111412, metersPerLatitudeDegree(60))
check(111618, metersPerLatitudeDegree(75))
check(111694, metersPerLatitudeDegree(90))

-- test 2D Tensor
local t = torch.Tensor{{0, 15, 30, 45}, {60, 75, 90, 0}}
local r = metersPerLatitudeDegree(t)
assert(r:dim() == 2)
assertEq(torch.Tensor{{110574, 110649, 110852, 111132},
                      {111412, 111618, 111694, 110574}},
         r,
         1)

-- test 1D Tensor
local t = torch.Tensor{0, 15, 30, 45, 60, 75, 90}
local r = metersPerLatitudeDegree(t)
vp(2, 'r', r)
assert(r:dim() == 1)
assertEq(torch.Tensor{110574, 110649, 110852, 111132, 111412, 111618, 111694},
         r,
         1)



print('ok metersPerLatittudeDegree')