-- knn_test.lua
-- unit test

require 'knn'
require 'makeVp'
require 'NamedMatrix'
require 'pp'
require 'Random'

local vp = makeVp(2, 'tester')
torch.manualSeed(123)

local function distancesTest(dimensionName, queryIndex, features)
   local vp = makeVp(2, 'distancesTest')
   vp(1, 'dimensionName', dimensionName, 'queryIndex', queryIndex, 'features', features)
   print('distancesTest stub: should determine and use average latitude')
   local columnIndex = features:columnIndex(dimensionName)
   local v = tensorViewColumn(features.t, columnIndex)
   local nSamples = v:size(1)
   local result = torch.Tensor(nSamples)
   for i = 1, nSamples do
      local diff = v[i] - v[queryIndex]
      v[i] = diff * diff
   end
   return v
end

local function distanceEuclideanOLD(featureName, queryTable, othersTable)
   local vp = makeVp(1, 'distanceEuclidean')
   local nSamples = othersTable[featureName]:size(1)
   local query = torch.Tensor{query[featureName]}
   local queryVector = torch.Tensor(query:storage(), 1, nSamples, 0)
   local othersVector = othersTable[featureName]
   local diffs = queryVector - othersVector
   local squaredDiffs = torch.cmul(diffs, diffs)
   vp(2, 'nSamples', nSamples, 'queryVector', queryVector, 'othersVector', othersVector)
   vp(2, 'diffs', diffs, 'squaredDiffs', squaredDiffs)
   stop()
   return squaredDiffs
end


   
local config = {
   nSamples = 10,
   nSlices = 2,
   maxK = 6,
   imputedFeatureNames = {'imputeA', 'imputeB'},
   distances = distancesTest,
   --distances = distancesSurface,
}

-- test knn.emptySlice
local nSamples = 3
local kMax = 2
local empty = knn.emptySlice(nSamples, kMax)
--knn.printSlice('empty', empty)

local function verifySize(tensor)
   assert(tensor:size(1) == nSamples)
   assert(tensor:size(2) == kMax)
end

verifySize(empty.distances.latitude)
verifySize(empty.distances.longitude)
verifySize(empty.distances.year)
verifySize(empty.indices.latitude)
verifySize(empty.indices.longitude)
verifySize(empty.indices.year)

-- test knn.mergeSlices
local nSamples = 3
local kMax = 2
local slice1 = knn.emptySlice(nSamples, kMax)
local slice2 = knn.emptySlice(nSamples, kMax)

local function set(slice, rowIndex, key)
   knn.printSlice('set slice', slice)
   slice.indices.latitude[rowIndex] = torch.LongTensor(kMax):fill(key)
   slice.indices.longitude[rowIndex] = torch.LongTensor(kMax):fill(key)
   slice.indices.year[rowIndex] = torch.LongTensor(kMax):fill(key)
   slice.distances.latitude[rowIndex] = torch.rand(kMax)
   slice.distances.longitude[rowIndex] = torch.rand(kMax)
   slice.distances.year[rowIndex] = torch.rand(kMax)
end

set(slice1, 1, 1)
set(slice1, 3, 1)
set(slice2, 2, 2)

knn.printSlice('slice1', slice1)
knn.printSlice('slice2', slice2)
local merged = knn.mergeSlices(slice1, slice2)
knn.printSlice('merged', merged)
pp.tensor('merged.indices.latitude', merged.indices.latitude)
assert(merged.indices.latitude[1][1] == 1)
assert(merged.indices.latitude[2][1] == 2)
assert(merged.indices.latitude[3][1] == 1)

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

-- see lab notes for 2014-04-02 for the derivation of these points
local function makeData4Points()
   local result = NamedMatrix{
      tensor = torch.Tensor(4,4):zero(),
      names={'latitude', 'longitude', 'year', 'HEATING.CODE'},
      levels={},
   }
   pp.table('result', result)

   local nextPointIndex = 0
   local function addPoint(latitude, longitude)
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
pp.table('features', features)

-- test makeSlice
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
