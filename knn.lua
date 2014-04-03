-- knn.lua
-- knn.emptySlice(nSamples, maxK) --> slice
-- knn.makeSlice(sliceIndex, nSlices, maxK, features, imputedFeatureNames, distances) --> slice
-- knn.mergeSlices(slice1, slice2) --> slice
-- knn.nearestNeighbors(imputedFeatureName, slice, k, mPerYear, queryIndex) --> distances, indices (in features)
-- knn.printSlice(name, value)  -- print on stdout
--
-- A slice is a table with 3 fields
--   slice.latitude
--   slice.longitude
--   slice.year
-- ... each of which is a table [queryIndex]{index, distance} where
--     - index is a sample index in features (a row index)
--     - distance is the squared distance along the dimension from the queryIndex sample to the sample
--       in features at the corresponding index
--
-- OLD
-- A Slice is a table with 6 fields, each a tensor of size nSamples x maxK
--   slice.distances.latitude
--   slice.distances.longitude
--   slice.distances.year
--   slice.indices.latitude
--   slice.indices.longitude
--   slice.indices.year
--
-- distances(dimensionName, features, queryIndex) --> distances, indices (for all samples)

knn = {}

require 'setUnion'
require 'tensorViewColumn'
require 'tensorViewPrefix'
require 'pp'

-- knn.emptySlice(): return a slice with no content
-- ARGS:
-- nSamples   : positive integer, nSamples
-- maxK       : positive integer
-- RETURNS:
-- emptySlice : NamedMatrix with no rows and no columns
function knn.emptySlice(nSamples, maxK)
   return {  
      distances = {
         latitude = torch.FloatTensor(nSamples, maxK):zero(),
         longitude = torch.FloatTensor(nSamples, maxK):zero(),
         year = torch.FloatTensor(nSamples, maxK):zero(),
      },
      indices = {
         latitude = torch.LongTensor(nSamples, maxK):zero(),
         longitude = torch.LongTensor(nSamples, maxK):zero(),
         year = torch.LongTensor(nSamples, maxK):zero(),
      },
   }
end

-- make the slice at a particular index, returning a slice
-- ARGS:
-- currentSlice        : number, current slice; currentSlice \in {1, 2, ..., nSlices}
-- nSlices             : postive integer, number of slices
-- maxK                : positive integer
-- features            : NamedMatrix of size nSamples x nFeatures
-- imputedFeatureNames : sequence of strings, each a column in features
-- distances           : function(dimensionName, queryIndex, features) --> vector of size nSamples
-- RETURNS
-- sliceResult         : Slice table with non-zero entries for currentSlice
function knn.makeSlice(currentSlice, nSlices, maxK, features, imputedFeatureNames, distances)
   local vp = makeVp(2, 'makeSlice')
   vp(1, 'currentSlice', currentSlice, 'nSlices', nSlices)

   assert(type(currentSlice) == 'number')
   assert(currentSlice >= 1)
   assert(type(nSlices) == 'number')
   assert(currentSlice <= nSlices)
   assert(type(maxK) == 'number')
   assert(maxK >= 1)
   assert(torch.typename(features) == 'NamedMatrix')
   assert(type(distances) == 'function')

   local nSamples = features.t:size(1)
   vp(2, 'nSamples', nSamples)

   local currentSlice = 0
   local function inCurrentSlice(sampleIndex, nSlices)
      currentSlice = currentSlice + 1
      if currentSlice > nSlices then
         currentSlice = currentSlice + 1
      end
      return currentSlice == currentSlice
   end

   local function maxKDistancesIndices(sampleIndex, dimensionName)
      local vp = makeVp(2, 'maxKDistancesIndices')
      vp(1, 'sampleIndex', sampleIndex, 'dimensionName', dimensionName)

      local allDistances = distances(dimensionName, sampleIndex, features)
      pp.tensor('allDistances', allDistances)
      local sorted, indices = torch.sort(allDistances)
      pp.tensor('sorted', sorted)
      print('indices', indices)
      pp.tensor('indices', indices)
      return tensorViewPrefix(sorted, maxK), tensorViewPrefix(indices, maxK)
   end

   local result = knn.emptySlice(nSamples, maxK)
   for sampleIndex = 1, nSamples do
      if inCurrentSlice(sampleIndex, nSlices) then
         for _, dimensionName in ipairs({'latitude', 'longitude', 'year'}) do
            local distances, indices = maxKDistancesIndices(sampleIndex, dimensionName)
            --printTableValue('result', result)
            result.distances[dimensionName][sampleIndex] = distances
            result.indices[dimensionName][sampleIndex] = indices
         end
      end
   end
   return result
end

-- merge non-zero rows of two tensors
local function mergerTensors(t1, t2)
   local nRows = t1:size(1)
   local nCols = t2:size(2)
   assert(t2:size(1) == nRows)
   assert(t2:size(2) == nCols)

   local result = t1:clone()
   for rowIndex = 1, nRows do
      for colIndex = 1, nCols do
         local t2Value = t2[rowIndex][colIndex]
         if t2Value ~= 0 then
            result[rowIndex][colIndex] = t2Value
         end
      end
   end
   return result
end

-- knn.mergeSlices
-- ARGS
-- slice1              : table with some samples with zero values
-- slice2              : table with other samples with zero values
-- RETURNS
-- mergedSlice         : table with merged elements (fewer zero values)
function knn.mergeSlices(slice1, slice2)
   local vp = makeVp(0, 'knn.mergeSlices')
   vp(1, 'slice1', slice1, 'slice2', slice2)

   local nSamples = slice1.distances.latitude:size(1)
   local kMax = slice1.distances.latitude:size(2)
   assert(slice2.distances.latitude:size(1) == nSamples)
   assert(slice2.distances.latitude:size(2) == kMax)

   local result = knn.emptySlice(nSamples, kMax)

   -- maybe mutate result by merging data from slice1 and slice2 into result
   local function maybeSetResult(dimensionName, rowIndex, colIndex)
      local vp, verboseLevel = makeVp(0, 'maybeSetResult')
      local slice1IndexValue = slice1.indices[dimensionName][rowIndex][colIndex]
      local slice2IndexValue = slice2.indices[dimensionName][rowIndex][colIndex]
      if slice1IndexValue == 0 then
         if slice2IndexValue == 0 then
            -- do nothing, as no data in either slice
         else
            -- use values in slice2, as slice1 is empty
            result.indices[dimensionName][rowIndex][colIndex] = slice2IndexValue
            result.distances[dimensionName][rowIndex][colIndex] = slice2.distances[dimensionName][rowIndex][colIndex]
            if verboseLevel > 0 then print('used values in slice2') end
         end
      else
         if slice2IndexValue == 0 then
            -- use values in slice1, as slice1 is empty
            result.indices[dimensionName][rowIndex][colIndex] = slice1IndexValue
            result.distances[dimensionName][rowIndex][colIndex] = slice1.distances[dimensionName][rowIndex][colIndex]
            if verboseLevel > 0 then print('used values in slice1') end
         else
            error('both slices have data dim %s rowIndex %f colIndex %f', dimensionName, rowIndex, colIndex)
         end
      end
   end

   for rowIndex = 1, nSamples do
      for colIndex = 1, kMax do 
         maybeSetResult('latitude', rowIndex, colIndex)
         maybeSetResult('longitude', rowIndex, colIndex)
         maybeSetResult('year', rowIndex, colIndex)
      end
   end

   vp(1, 'result', result)
   return result
end

-- knn.nearestNeighbors
-- ARGS
-- features           : NamedMatrix
-- imputedFeatureName : string
--                      only neighbors with a present value are considered as possible neighbors
-- slice              : table
-- k                  : positive integer <= maxK
-- mPerYear           : number, used to convert distance in years to distance in meters
-- queryIndex         : index in {1, ..., nSamples} of query
-- RETURNS
-- distances          : in features of nearest k locations to queryIndex
-- indices            ; in features of nearest k locations to queryIndex
function knn.nearestNeighbors(features, imputedFeatureName, slice, k, mPerYear, queryIndex)
   local vp, verboseLevel = makeVp(2, 'knn.nearestNeighbors')
   vp(1, 'features', features, 'imputedFeatureName', imputedFeatureName, 'slice', slice)
   vp(1, 'k', k, 'mPerYear', mPerYear, 'queryIndex', queryIndex)

   local nSamples = features.t:size(1)
   local maxK = slice.distances.latitude:size(2)
   
   -- would be fast if structure were slice[dimension]{index,distance}
   local function getDistanceDimension(dimension)
      local d = torch.Tensor(nSample):fill(math.huge)

      for index, distance in pairs(slice[dimension][queryIndex]) do
         d[index] = distance
      end
      
      return d
   end

   local distanceDimension = {
      latitude = getDistanceDimension('latitude'),
      longitude = getDistanceDimesion('longitude'),
      year = getDistanceDimension('year') * (mPerYear * mPerYear)
   }

   local distances = (distanceDimension.latitude + distanceDimension.longitude + distanceDimension.year):sqrt()
   local sorted, indices = distances:sort()
   return tensorViewPrefix(sorted), tensorViewPrefix(indices)
end

-- knn.printSlice: print a slice
-- ARGS:
-- name  : string
-- slice : slice value (a table)
-- RETURNS: nil
function knn.printSlice(name, slice)
   pp.table(name, slice)
   for key1 in pairs(slice) do
      for key2 in pairs(slice[key1]) do
         pp.tensor(name .. '.' .. key1 .. '.' .. key2, slice[key1][key2])
      end
   end
end
