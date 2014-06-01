-- program_knn_timing.lua
-- determine timing of both knn function on the full data set

require 'distanceTime2'
require 'knn'
require 'pp'
require 'readImputationData'
require 'surfaceDistanceSpace2'
require 'Timer'

local function test(readlimit)
   local features, numberColumns, factorColumns = readImputationData(readlimit)
   
   local queryIndeix = 1
   maxK = 256

   local timer= Timer()
   local knnInfo = knn.knnInfo(queryIndex, features, maxK, surfaceDistanceSpace2, distanceTime2)
   local cpu, wallclock = timer:cpuWallclock()
   print(string.format('sec for knnInfo for one sample: cpu %f wallclock %f', cpu, wallclock))

   local k = 60
   local pPerYear = 300
   local featureName = 'HEATING.CODE'

   local timer = Timer()
   local n, indices, distances2 = knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)
   local cpu, wallclock = timer:cpuWallclock()
   print(string.format('sec for nearestKnown for one sample: cpu %f wallclock %f', cpu, wallclock))
      
   print('n', n)
   print('distances to nearest neighbors')
   for i = 1, n do
      print(string.format('index %3d distance^2 %9.6f', indices[i], distances2[i]))
   end
end

test(10)  -- check if code works

test(-1)  -- the real test on all the samples
