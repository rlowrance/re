-- imputeMissingFeature_test.lua
-- selective unit tests of functions in imputeMissingFeature.lua

require 'imputeMissingFeature'
require 'makeVp'

local verbose = 2
local vp = makeVp(verbose, 'tester')

-- TEST getWeights
torch.manualSeed(123)
local nObs = 10
local cLatitude = 1
local cLongitude = 2
local cYear = 3

local trainingLocations = torch.Tensor(nObs, 3)
for i = 1, nObs do
   trainingLocations[i][cLatitude] = torch.uniform(0,1) * 90
   trainingLocations[i][cLongitude] = - torch.uniform(0,1) * 180
   trainingLocations[i][cYear] = math.floor(1950 + torch.uniform(0,1) * 50)
end

local queryLocation = torch.Tensor(3)
queryLocation[cLatitude] = 45
queryLocation[cLongitude] = -118
queryLocation[cYear] = 1960

local hp = {mPerYear=100, k=1}

local names = {'G LATITUDE', 'G LONGITUDE', 'YEAR.BUILT'}

local weights = getWeights(trainingLocations,
                           queryLocation,
                           hp,
                           names)

error('write test')

print('ok ImputeMissingFeature')