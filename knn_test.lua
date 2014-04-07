-- knn_test.lua
-- unit test

-- load correct implementation
local implementation = 2
if implementation == 1 then
   require 'knn_implementation_1'
elseif implementation == 2 then
   require 'knn_implementation_2'
else
   error(string.format('implementation = %s', tostring(implementation)))
end

require 'makeVp'
require 'NamedMatrix'
require 'pp'
require 'Random'
require 'tableCopy'
require 'tensor'

local vp = makeVp(2, 'tester')
torch.manualSeed(123)

-- test harness
local function kNearestNeighbors(queryIndex, features, featureName, k, maxK, mPerYear)
   if implementation == 1 then
      local knnInfo = knn.knnInfo(queryIndex, features, maxK)
      local n, indices, distances = knn.nearestKnown(queryIndex, features, knnInfo, k, mPerYear, featureName)
      return n, indices, distances, knnInfo
   elseif implementation == 2 then
      local knnInfo = knn.knnInfo(queryIndex, features, featureName, maxK)
      local n, indices, distances = knn.nearestKnown(knnInfo, k, mPerYear)
      return n, indices, distances, knnInfo
   else
      error(string.format('implementation = %s', tostring(implementation)))
   end
end

-- test small example with known results
   
-- see lab notes for 2014-04-02 for the derivation of these points
local function makeData4Points()
   local result = NamedMatrix{
      tensor = torch.Tensor(4,4):zero(),
      names={'latitude', 'longitude', 'year', 'HEATING.CODE'},
      levels={},
   }
   pp.table('result', result)

   local nextPointIndex = 0
   local function addPoint(longitude, latitude)
      -- add point at <latitude,longitude,0> to result
      nextPointIndex = nextPointIndex + 1
      result.t[nextPointIndex][result:columnIndex('latitude')] = latitude
      result.t[nextPointIndex][result:columnIndex('longitude')] = longitude
      result.t[nextPointIndex][result:columnIndex('year')] = 2014
      result.t[nextPointIndex][result:columnIndex('HEATING.CODE')] = 14  -- arbitrary non-zero value 
   end

   addPoint(0, 0) -- A
   addPoint(1, 5) -- B
   addPoint(2, 2) -- C
   addPoint(3, 1) -- D

   return result
end

local function equalDimension(d, seq, tolerance)
   for index, distance in pairs(d) do
      assertEq(distance, seq[index], tolerance)
   end
end

-- test1: 4 points with maxK == 4
local function test1(maxK, expectedIndices, expectedDistances)
   print('\n*********************')
   local vp = makeVp(2, 'test4good')
   vp(1, 'expectedIndices', expectedIndices, 'expectedDistances', expectedDistances)
   local queryIndex = 1
   local features = makeData4Points()
   local featureName = 'HEATING.CODE'
   local mPerYear = .1
   for k = 2, maxK do
      local n, indices, distances, nearestMaxK = kNearestNeighbors(queryIndex, features, featureName, k, maxK, mPerYear)
      vp(1, '************** k', k, 'maxK', maxK)
      vp(1, 'indices', indices, 'distances', distances, 'nearestMaxK', nearestMaxK)
      vp(1, 'prefix of expectedIndices', tensorViewPrefix(expectedIndices, k))
      assertEq(indices, tensorViewPrefix(expectedIndices, k), 0)
      assertEq(distances, tensorViewPrefix(expectedDistances, k), 0.001)
   end
end

if true then
   test1(4, torch.Tensor({1,3,4,2}),torch.Tensor({0,8,10,26}):sqrt())
end

-- test2: 4 points with maxK == 3
local function test2(maxK, expectedIndices, expectedDistances)
   print('\n*********************')
   local vp = makeVp(2, 'test4good')
   vp(1, 'expectedIndices', expectedIndices, 'expectedDistances', expectedDistances)
   local queryIndex = 1
   local features = makeData4Points()
   local featureName = 'HEATING.CODE'
   local mPerYear = .1
   for k = 2, maxK do
      local n, indices, distances, knnInfo = kNearestNeighbors(queryIndex, features, featureName, k, maxK, mPerYear)
      vp(1, '************** k', k, 'maxK', maxK)
      vp(1, 'indices', indices, 'distances', distances, 'knnInfo', knnInfo)
      vp(1, 'expectedIndices', expectedIndices)
      vp(1, 'n', n)
      assert(n == 1)
      assert(indices:size(1) == 1)
      assert(distances:size(1) == 1)
      assert(indices[1] == expectedIndices[1])
      assertEq(distances[1], expectedDistances[1], 0.001)
   end
end

if true then
   test2(3, torch.Tensor({3}), torch.Tensor({8}):sqrt())
end

-- test3: 4 points with maxK == 2
local function test3(maxK, expectedIndices, expectedDistances)
   print('\n*********************')
   local vp = makeVp(2, 'test4good')
   vp(1, 'expectedIndices', expectedIndices, 'expectedDistances', expectedDistances)
   local queryIndex = 1
   local features = makeData4Points()
   local featureName = 'HEATING.CODE'
   local mPerYear = .1
   for k = 2, maxK do
      local n, indices, distances, nearestMaxK = kNearestNeighbors(queryIndex, features, featureName, k, maxK, mPerYear)
      vp(1, '************** k', k, 'maxK', maxK)
      vp(1, 'indices', indices, 'distances', distances, 'nearestMaxK', nearestMaxK)
      vp(1, 'prefix of expectedIndices', tensorViewPrefix(expectedIndices, k))
      assert(n == 0)
   end
end

if true then
   test3(2, torch.Tensor({3}), torch.Tensor({8}):sqrt())
end

local function makeData100Points(nSamples)
   assert(nSamples >= 4)
   local nFeatures = 4
   local result = NamedMatrix{
      tensor = torch.Tensor(nSamples, nFeatures):zero(),
      names={'latitude', 'longitude', 'year', 'HEATING.CODE'},
      levels={},
   }
   --pp.table('result', result)

   local nextPointIndex = 0
   local function addPoint(longitude, latitude)
      -- add point at <latitude,longitude,0> to result
      nextPointIndex = nextPointIndex + 1
      result.t[nextPointIndex][result:columnIndex('latitude')] = latitude
      result.t[nextPointIndex][result:columnIndex('longitude')] = longitude
      result.t[nextPointIndex][result:columnIndex('year')] = 2014
      result.t[nextPointIndex][result:columnIndex('HEATING.CODE')] = 14  -- arbitrary non-zero value 
   end

   addPoint(0, 0) -- A
   addPoint(2, 2) -- C
   addPoint(3, 1) -- D

   -- add the B points at coordinates (1 + delta, 5 + delta)
   for n = 1, nSamples - 3 do
      local delta = n / nSamples
      addPoint(1 + delta, 5 + delta)
   end

   return result
end

local function test4()
   print('\n*************** test4 **************************')
   local nSamples = 100

   local queryIndex = 1
   local features = makeData100Points(nSamples)
   local maxK = nSamples - 3
   local k = 3
   local mPerYear = 0
   local featureName = 'HEATING.CODE'

   local n, indices, distances, info = kNearestNeighbors(queryIndex, features, featureName, k, maxK, mPerYear)
   pp.table('info', info)

   vp(1, 'n', n, 'indices', indices, 'distances', distance)

   -- test that indices 2 and 3 are not in the solution set
   for i = 1, n do
      local index = indices[i]
      assert(index ~= 2)
      assert(index ~= 3)
   end
end

if true then
   test4()
end

local function test_implementation_2_knnInfo_function()
   local nan = 0 / 0
   local featureName = 'HEATING.CODE'

   local function makeFeatures4(allPresent)
      local longitudes = torch.Tensor{0, 1, 2, 3}
      local latitudes = torch.Tensor{0, 5, 2, 1}
      local years = torch.Tensor{0, 0, 0, 0}
      local heatingCode = torch.Tensor{1, 2, 3, 4}
      if not allPresent then
         heatingCode = torch.Tensor{1, nan, 3, nan}
      end
      local tensor = tensor.concatenateHorizontally(longitudes, latitudes, years, heatingCode)
      local features = NamedMatrix{tensor = tensor, 
                                   names = {'longitude', 'latitude', 'year', featureName},
                                   levels = {}}
      return features
   end
   
   -- first test: all points present
   local queryIndex = 1
   local maxK = 4
   local allPresent = true
   local knnInfo = knn.knnInfo(queryIndex, makeFeatures4(allPresent), featureName, maxK)
   pp.table('knnInfo', knnInfo)
   -- check that every point is present in the maxK nearest neighbors
   assert(knnInfo.latitude[1])
   assert(knnInfo.latitude[2])
   assert(knnInfo.latitude[3])
   assert(knnInfo.latitude[4])

   assert(knnInfo.longitude[1])
   assert(knnInfo.longitude[2])
   assert(knnInfo.longitude[3])
   assert(knnInfo.longitude[4])

   -- second tests: two point are not present
   -- not present ponts are B and D (indices 2 and 4)
   local queryIndex = 1
   local maxK = 4
   local allPresent = true
   local knnInfo = knn.knnInfo(queryIndex, makeFeatures4(not allPresent), featureName, maxK)
   print('************')
   pp.table('knnInfo', knnInfo)
   -- check that only points 1 and 3 are present in the maxK nearest neighbors
   assert(knnInfo.latitude[1])
   assert(not knnInfo.latitude[2])
   assert(knnInfo.latitude[3])
   assert(not knnInfo.latitude[4])
   
   assert(knnInfo.longitude[1])
   assert(not knnInfo.longitude[2])
   assert(knnInfo.longitude[3])
   assert(not knnInfo.longitude[4])

   -- third test: two points not present and maxK = 1
   local queryIndex = 1
   local maxK = 1
   local allPresent = true
   local knnInfo = knn.knnInfo(queryIndex, makeFeatures4(not allPresent), featureName, maxK)
   print('************')
   pp.table('knnInfo', knnInfo)
   -- check that only points 1 is present in the maxK nearest neighbors
   assert(knnInfo.latitude[1])
   assert(not knnInfo.latitude[2])
   assert(not knnInfo.latitude[3])
   assert(not knnInfo.latitude[4])
   
   assert(knnInfo.longitude[1])
   assert(not knnInfo.longitude[2])
   assert(not knnInfo.longitude[3])
   assert(not knnInfo.longitude[4])
end

local function test_implementation_2_nearestKnown_function()
   -- build a suitable knnInfo table
   knnInfo = {
      maxK = 4,
      nSamples = 4,
      latitude = {[1] = 10, [2] = 20, [4] = 40},
      longitude = {[2] = 20, [4] = 40},
      year = {[4] = 40},
   }
   pp.table('knnInfo', knnInfo)
   local n, indices, distances = knn.nearestKnown(knnInfo, 2, 1)
   vp(1, 'n', n, 'indices', indices, 'distances', distances)
   assert(n == 1)
   assert(indices[1] == 4)
   assertEq(distances[1], math.sqrt(3 * 40), 0.0001)
end

if implementation == 2 then
   test_implementation_2_knnInfo_function()
   test_implementation_2_nearestKnown_function()
end

local function test_large()
   print('\n**************** test_large')
   local nan = 0 / 0

   local function makeImputedFeatureName(n)
      return string.format('imputedfeature' .. tostring(i))
   end

   local function makeImputedFeature(nSamples, missingFrequency)
      local result = Random:integer(nSamples, 1, 20) -- values are level numbers
      for i = 1, nSamples do
         if math.random() < missingFrequency then
            result[i] = nan
         end
      end
      return result
   end

   local function makeFeatures(nSamples, nImputedFeatures, missingFrequency)
      assert(missingFrequency)

      local function concat(a,b)
         local vp = makeVp(1, 'concat')
         vp(1, 'a', a, 'b', b)
         return tensor.concatenateHorizontally(a, b)
      end

      local tensor = {}
      local names = {}

      table.insert(names, 'latitudes')
      local latitudes = torch.rand(nSamples)

      table.insert(names, 'longitudes')
      tensor = concat(latitudes, torch.rand(nSamples))

      table.insert(names, 'years')
      tensor = concat(tensor, Random():integer(nSamples, 1, 50))
      
      for i = 1, nImputedFeatures do
         table.insert(names, imputedFeatureNames(i))
         tensor = concat(tensor, makeImputedFeatures(nSamples, missingFrequency))
      end

      vp(2, 'tensor', tensor, 'names', names)

      local result = NamedMatrix{
         tensor = tensor,
         names = names,
         levels = {},
      }

      return result
   end

   local nSamples = 1200000  -- 1.2 million
   local nSamples = 5
   local nImputedFeatures = 20
   local nImputedFeatures = 3
   local missingFrequency = .67
   local features = makeFeatures(nSamples, nImputedFeatures, missingFrequency)
   local featureName = features.names[features.t:size(2)]  -- last imputed feature name
   
   local queryIndex = 3
   local maxK = 3 * 120
   local knnInfo = knn.knnInfo(queryIndex, features, featureName, maxK)
   pp.table('knnInfo', knnInfo)
   
   local k = 4
   local mPerYear = 500
   local n, indices, distances = knn.nearestKnown(knnInfo, k, mPerYear)
   vp(2, 'n', n, 'indices', indices, 'distances', distances)
   error('write tests')
end

test_large()

error('test missing feature in HEATING.CODE')




-- OLD BELOW ME


-- make the test data
local function makeNamedMatrixInteger(nRows, lowest, highest, featureName)
   local vp = makeVp(0, 'makeNamedMatrixInteger')
   vp(1, 'nRows', nRows)
   local tVector = Random():integer(nRows, lowest, highest)
   local tMatrix = torch.Tensor(tVector:storage(), 1, nRows, 1, 1, 0)
   vp(2, 'tVector', tVector, 'tMatrix', tMatrix)
   return NamedMatrix{
      tensor = tMatrix,
      names = {featureName},
      levels = {},
   }
end

local function makeNamedMatrixRandom(nRows, featureName)
   local tVector = torch.rand(nRows)
   local tMatrix = torch.Tensor(tVector:storage(), 1, nRows, 1, 1, 0)
   return NamedMatrix{
      tensor = tMatrix,
      names = {featureName},
      levels = {},
   }
end

local function makeDataRandom(nSamples, imputedFeatureNames)
   local vp = makeVp(0, 'makeData')
   vp(1, 'nSamples', nSamples, 'imputedFeatureNames', imputedFeatureNames)
   local latitude = makeNamedMatrixRandom(nSamples, 'latitude')
   local longitude = makeNamedMatrixRandom(nSamples, 'longitude')
   local year = makeNamedMatrixInteger(nSamples, 1, 3, 'year')
   vp(2, 'latitude', latitude)
   local result = NamedMatrix.concatenateHorizontally(latitude, longitude)
   vp(2, 'result concat latitude longitude', result)
   vp(2, 'year', year)
   local result = NamedMatrix.concatenateHorizontally(result, year)
   for _, imputedFeatureName in ipairs(imputedFeatureNames) do
      local imputedFeature = makeNamedMatrixInteger(nSamples, 0, 1, imputedFeatureName)
      vp(2, 'imputedFeature', imputedFeature)
      result = NamedMatrix.concatenateHorizontally(result, imputedFeature)
   end
   vp(1, 'result', result)
   return result
end


-- return NamedMatrix
local function makeData(name, p1, p2)
   if name == '4 points' then
      return makeData4Points()
   elseif name == 'random' then
      return makeDataRandom(p1, p2)
   else
      error('not yet implemented: ' .. tostring(name))
   end
end


-- test using the 4 specially chosen points and one big slice
local features = makeData('4 points')


-- test makeSlice
if false then
   local nSamples = 4
   local maxK = 4
   local slices = knn.emptySlice(nSamples, maxK)
   config.nSlices = 1
   printTableValue('config', config)
   for sliceIndex = 1, config.nSlices do
      local slice = knn.makeSlice(sliceIndex,
      config.nSlices,
      maxK,
      features,
      config.imputedFeatureNames,
      config.distances)
      --vp(2, 'sliceIndex', sliceIndex, 'slice[sliceIndex]', slice[sliceIndex])
      knn.printSlice('slice', slice)
      slices = knn.mergeSlices(slices, slice)
      knn.printSlice('mutated slices', slices)
   end
end


-- examine metrics for observation 1
print('results for observation 1')
pp.tensor('obs 1 indices longitude', slices.indices.longitude[1])
pp.tensor('obs 1 indices latitude', slices.indices.latitude[1])
pp.tensor('obs 1 indices year', slices.indices.year[1])

pp.tensor('obs 1 distances longitude', slices.distances.longitude[1])
pp.tensor('obs 1 distances latitude', slices.distances.latitude[1])
pp.tensor('obs 1 distances year', slices.distances.year[1])

local distances, indices = knn.nearestNeighbors(features, 'HEATING.CODE', slices, 2, 0, 1)
pp.tensor('distance', distances)
pp.tensor('indices', indices)

error('test slices table')

error('write more')

print('ok knn')
