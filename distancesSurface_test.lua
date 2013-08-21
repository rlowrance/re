-- distancesSurface_test.lua
-- unit test

require 'distancesSurface'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- inputs are sequences of tables
function location(latitude, longitude, year)
   return torch.Tensor{latitude, longitude, year}
end

local query = location(30.0, -150, 2010)
local others = torch.Tensor(4, 3)
others[1] = location(30.0, -150, 2010)
others[2] = location(31.0, -150, 2010)
others[3] = location(30.0, -151, 2010)
others[4] = location(30.0, -150, 2011)

local mPerYear = 1000

local names = {latitude=1, longitude=2, year=3}
local distances = distancesSurface(query, 
                                   others, 
                                   mPerYear, 
                                   names)
vp(1, 'distances', distances)


function check(a, b)
   local tolerance = 1
   assert(math.abs(a - b) < tolerance)
end

check(0, distances[1])
check(110861, distances[2])
check(96486, distances[3])
check(mPerYear, distances[4])

print('ok distancesSurface')
