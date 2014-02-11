-- getWeights_test.lua
-- unit test

require 'makeVp'
require 'getWeights'

local vp = makeVp(2, 'tester')

local function makeLocation(latDegrees, latMinutes, longDegrees, longMinutes, yearFounded)
   local latitude = latDegrees + (latMinutes / 60)
   local longitude = - (longDegrees + (longMinutes / 60))
   return {latitude = latitude, longitude = longitude, year=yearFounded}
end

-- locations
locations = {}
locations.LosAngeles = makeLocation(34,3,118,15, 1781)
locations.Atlanta = makeLocation(33,34,84,23, 1837)
locations.Chicago = makeLocation(41,50,87,37, 1892)
locations.NewYork = makeLocation(40,47,73,58, 1664)

-- distances in kilometers from New York
distance = {}
distance.LosAngeles = 3944
distance.Atlanca = 1198
distance.Chicago = 1149

-- hyperparameters
hp = {}
hp.k = 2
hp.mPerYear = 1000

local names =  {'G LATITUDE', 'G LONGITUDE', 'YEAR.BUILT'}
local cLatitude = 1
local cLongitude = 2
local cYearBuilt = 3

local function makeTrainingLocations(locations)
   local vp = makeVp(1, 'makeTrainingLocations')
   vp(1, 'locations', locations)
   local trainingLocations = torch.Tensor(3, 3)
   local trainingLocationIndex = 0
   for city, location in pairs(locations) do
      if city ~= 'NewYork' then
         locationIndex = locationIndex + 1
         locations[locationIndex][cLatitude] = location.latitude
         locations[locationIndex][cLongitude] = location.longitude
         locations[locationIndex][cYearBuilt] = location.year
      end
   end
   vp(1, 'trainingLocations', trainingLocations)
   return trainingLocations
end

local function makeNewYorkLocation(locations)
   local vp = makeVp(1, 'makeNewYorkLocation')
   vp(1, 'locations', locations)
   local t = torch.Tensor(3)
   t[cLatitude] = locations.NewYork.latitude
   t[cLongitude] = locations.NewYork.longitude
   t[cYearBuilt] = locations.NewYork.year
   vp(1, 't', t)
   return t
end

local weights, distances = getWeights(makeTrainingLocations(locations),
                                      makeNewYorkLocation(locations),
                                      hp, 
                                      names)
printTableValue('weights', weights)
printTableValue('distance', distances)
error('write tests')

-- test various years built
print('ok getWeights')
