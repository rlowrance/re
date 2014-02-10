-- distancesSurface2_test.lua
-- unit test
-- test is probably from Wikipedia 

require 'distancesSurface2'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- inputs are sequences of tables
function location(latitude, longitude, year)
   return torch.Tensor{latitude, longitude, year}
end

local query = {
   latitude = 30,
   longitude = -150,
   year = 2010
}

local others = {
   latitude = torch.Tensor{30, 31, 30, 30},
   longitude = torch.Tensor{-150, -150, -151, -150},
   year = torch.Tensor{2010, 2010, 2010, 2011},
}

local mPerYear = 1000

local distances = distancesSurface2(query, 
                                   others, 
                                   mPerYear)
vp(1, 'distances', distances)


function check(a, b)
   local tolerance = 1
   assert(math.abs(a - b) < tolerance)
end

check(0, distances[1])
check(110861, distances[2])
check(96486, distances[3])
check(mPerYear, distances[4])

print('ok distancesSurface2')
