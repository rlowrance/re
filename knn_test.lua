-- knn_test.lua
-- unit test

require 'knn'
require 'makeVp'
require 'NamedMatrix'
require 'pp'
require 'Random'
require 'tensor'

local function euclideanSpace2(features, queryIndex)
   local vp, verboseLevel = makeVp(0, 'euclideanDistanceSpace2')
   local debug = verboseLevel > 0
   vp(1, 'features', features, 'queryIndex', queryIndex)
   local nSamples = features.t:size(1)

   local columnLatitude = features:columnIndex('latitude')
   local columnLongitude = features:columnIndex('longitude')

   local latitudes = tensor.viewColumn(features.t, columnLatitude)
   local longitudes = tensor.viewColumn(features.t, columnLongitude)

   local deltaLatitudes = latitudes - torch.Tensor(nSamples):fill(features.t[queryIndex][columnLatitude])
   local deltaLongitudes = longitudes - torch.Tensor(nSamples):fill(features.t[queryIndex][columnLongitude])

   local result = torch.cmul(deltaLatitudes, deltaLatitudes) + torch.cmul(deltaLongitudes, deltaLongitudes)
   if debug then
      pp.tensor('features.t', features.t)
      pp.tensor('result', result)
   end
   return result:type('torch.FloatTensor')
end

local function euclideanTime2(features, queryIndex)
   local vp, verboseLevel = makeVp(0, 'euclideanDistanceTime2')
   local debug = verboseLevel > 0

   vp(1, 'features', features, 'queryIndex', queryIndex)
   local nSamples = features.t:size(1)
   local columnYear = features:columnIndex('year')
   local years = tensor.viewColumn(features.t, features:columnIndex('year'))
   local deltas = years - torch.Tensor(nSamples):fill(features.t[queryIndex][columnYear])
   local result = torch.cmul(deltas, deltas)
   if debug then
      pp.tensor('features.t', features.t)
      pp.tensor('result', result)
   end
   return result:type('torch.FloatTensor')
end

local function makeFeatures(t)
   local result = NamedMatrix{
      tensor = tensor.concatenateHorizontally(t.latitude, t.longitude, t.year, t.heating),
      names = {'latitude', 'longitude', 'year', 'heating'},
      levels = {},
   }
   return result
end

local function testSmallEuclideanAllPresent()
   local vp, verboseLevel = makeVp(0, 'testSmallEuclideanAllPresent')
   local debug = verboseLevel > 0

   local features = makeFeatures{
      latitude = torch.Tensor{0,5,2,1},
      longitude = torch.Tensor{0,1,2,3},
      year = torch.Tensor{1,0,1,3},
      heating = torch.Tensor{1,2,3,4},  -- sample 3 is not present

   }
   vp(2, 'features', features)
   if debug then pp.table('features', features) end

   local queryIndex = 1
   local maxK = 4
   local knnInfo = knn.knnInfo(queryIndex, features, maxK, euclideanSpace2, euclideanTime2)
   vp(2, 'knnInfo', knnInfo)
   if debug then pp.table('knnInfo', knnInfo) end

   local k = 3
   local mPerYear = 1
   local featureName = 'heating'
   local n, indices, distances2 = knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)
   vp(2, 'n', n, 'indices', indices, 'distances2', distances2)
   if debug then pp.variables('indices', 'distances2') end

   assert(n == 3)
   assert(indices[1] == 1 and distances2[1] == 0)
   assert(indices[2] == 3 and distances2[2] == 8)
   assert(indices[3] == 4 and distances2[3] == 14)
end

local function testSmallEuclideanSomeMissing()
   local vp, verboseLevel = makeVp(0, 'testSmallEuclideanSomeMissing')
   local debug = verboseLevel > 0

   local nan = 0 / 0
   local features = makeFeatures{
      latitude = torch.Tensor{0,5,2,1},
      longitude = torch.Tensor{0,1,2,3},
      year = torch.Tensor{1,0,1,3},
      heating = torch.Tensor{1,2,nan,4},  -- feature not present in sample 3
   }
   if debug then
      vp(2, 'features', features)
      pp.table('features', features)
   end

   local queryIndex = 1
   local maxK = 4
   local knnInfo = knn.knnInfo(queryIndex, features, maxK, euclideanSpace2, euclideanTime2)
   if debug then 
      vp(2, 'knnInfo', knnInfo)
      pp.table('knnInfo', knnInfo)
   end

   local k = 3
   local mPerYear = 1
   local featureName = 'heating'
   local n, indices, distances2 = knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)
   if debug then
      vp(2, 'n', n, 'indices', indices, 'distances2', distances2)
      pp.variables('indices', 'distances2')
   end
   assert(n == 3)
   assert(indices[1] == 1 and distances2[1] == 0)
   assert(indices[2] == 4 and distances2[2] == 14)
   assert(indices[3] == 2 and distances2[3] == 27)
end

local function testSmallEuclidean()
   testSmallEuclideanAllPresent()
   testSmallEuclideanSomeMissing()
end

if true then
   testSmallEuclidean()
else
   print('re-enable testSmallEuclidean')
end

local function testLargeEuclidean()
   local vp, verboseLevel = makeVp(0, 'testLargeEuclidean')
   local debug = verboseLevel > 0

   local nSamples = 1.2e6
   --local nSamples = 20
   --local nSamples = 100
   local nImputedFeatures = 20
   local imputedPresentFrequency = .5
   local nan = 0 / 0

   local function replace(tensor, oldValue, newValue)
      return tensor:apply(function (x) 
         if x == oldValue then 
            return newValue 
         end
      end)
   end

   local features = makeFeatures{
      latitude = torch.rand(nSamples),
      longitude = torch.rand(nSamples),
      year = Random():integer(nSamples, 1900, 1999),
      heating = replace(Random():integer(nSamples, 0, 1), 0, nan),
   } 
   if debug then
      pp.table('features', features)
      pp.tensor('features.t', features.t)
   end

   local queryIndex = 1
   local maxK = 10
   local knnInfo = knn.knnInfo(queryIndex, features, maxK, euclideanSpace2, euclideanTime2)
   if debug then
      vp(2, 'knnInfo', knnInfo)
      pp.table('knnInfo', knnInfo)
      pp.knnInfo(knnInfo)
   end
         

   local k = 3
   local mPerYear = 1
   local featureName = 'heating'
   local n, indices, distances2 = knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)
   if debug then
      vp(2, 'n', n, 'indices', indices, 'distances2', distances2)
      pp.variables('indices', 'distances2')
   end

   assert(n == 3)
   assert(indices[1] == 1 and distances2[1] == 0 or (isnan(features.t[1][4])))
end

testLargeEuclidean()

print('ok knn')
