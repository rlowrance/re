-- knn.lua
-- compute nearest neighbors with known features and varying mPerYear
--
-- knn.nearestMaxK(queryIndex, features, maxK) 
--   --> nearestMaxK table
-- knn.nearestKnown(queryIndex, features, nearestMaxK, k, mPerYear, featureName) 
--   --> n, indices (in features), distances
--
-- with types
--   queryIndex           : positive integer, row number in features
--   features             : NamedMatrix with rows = samples and columns = features
--   maxK                 : positive integer
--   k                    : positive integer <= maxK
--   mPerYear             : number of meters in one year of distance
--   nearestMaxK         : opaque table with info on the maxK neighbors of a specific queryIndex in features
--   n                    : 0 <= integer <= k, number of neighbors with known feature values found
--
-- In this implementation, nearestMaxK contains these fields with distances along the specified dimensions
-- .queryIndex            : number
-- .maxK                  : number
-- .latitude              : table with key = index of neighbor, value = squared distance from queryIndex
-- .longitude             : table with same structure
-- .year                  : table with same structure

knn = {}

require 'makeVp'
require 'tensorViewColumn'
require 'tensorViewPrefix'
require 'pp'

local function ppDimension(dimensionName, table)
   for key, value in pairs(table) do
      print(string.format(' %s[%d]=%f', dimensionName, key, value))
   end
end

local function ppDimensionDistances(name, value)
   print('nearestMaxK', name)
   ppDimension('latitude', value.latitude)
   ppDimension('longitude', value.longitude)
   ppDimension('year', value.year)
   stop()
end

-- return nearestMaxK table
function knn.nearestMaxK(queryIndex, features, maxK)
   local vp, verboseLevel = makeVp(0, 'knn.nearestMaxK')

   vp(1, 'queryIndex', queryIndex, 'features', features, 'maxK', maxK)
   if verboseLevel > 0 then pp.tensor('features.t', features.t) end

   local nSamples = features.t:size(1)

   local function squaredDistances(dimensionName)
      local vp = makeVp(0, 'squaredDistance')
      vp(1, 'dimensionName', dimensionName)
      local columnIndex = features:columnIndex(dimensionName)
      local queryValue = features.t[queryIndex][columnIndex]
      local queryVector = torch.Tensor{queryValue}
      local queries = torch.Tensor(queryVector:storage(), 1, nSamples, 0)
      local others = tensorViewColumn(features.t, columnIndex)
      local differences = queries - others
      vp(2, 'columnIndex', columnIndex)
      vp(2, 'queryValue', queryValue)
      vp(2, 'queryVector', queryVector)
      vp(2, 'queries', queries)
      vp(2, 'others', others)
      vp(2, 'difference', difference)
      local result = torch.cmul(differences, differences)
      vp(1, 'result', result)
      return result
   end

   local function makeInfoDimension(dimensionName)
      local vp, verboseLevel = makeVp(0, 'makeInfoDimension')
      vp(1, 'dimensionName', dimensionName)
      local distancesSquared = squaredDistances(dimensionName)
      vp(2, 'distancesSquared', distancesSquared)
      local sortedDistancesSquared, indices = torch.sort(distancesSquared)
      vp(2, 'sorted', sorted, 'indices', indices)
      local result = {}
      for i = 1, maxK do
         result[indices[i]] = sortedDistancesSquared[i]
      end
      vp(1, 'result', result)
      if verboseLevel > 0 then ppDimension('result for ' .. dimensionName, result) end
      return result
   end

   local result = {
      queryIndex = queryIndex,
      maxK       = maxK,
      latitude   = makeInfoDimension('latitude'),
      longitude  = makeInfoDimension('longitude'),
      year       = makeInfoDimension('year'),
   }

   if verboseLevel > 0 then ppDimensionDistances('result from nearestMaxK', result) end
   return result
end

local function printFiniteValues(name, tensor)
   print(string.format('finite and non-NaN values in tensor %s', name))
   for i = 1, tensor:size(1) do
      local value = tensor[i]
      if isnan(value) or math.abs(value) == math.huge then
         -- do nothing
      else
         print(string.format(' [%d]=%f', i, value))
      end
   end
end


-- return up to k indices (in features), distances (corresponding to indices)
-- NOTE: may return less than k nearest neighbors
function knn.nearestKnown(queryIndex, features, nearestMaxK, k, mPerYear, featureName)
   local vp, verboseLevel = makeVp(2, 'knn.nearestKnown')
   vp(1, 'queryIndex', queryIndex, 'features', features, 'nearestMaxK', nearestMaxK)
   vp(1, 'k', k, 'mPerYear', mPerYear)

   assert(queryIndex == nearestMaxK.queryIndex)
   assert(k <= nearestMaxK.maxK)

   local nSamples = features.t:size(1)

   -- return vector of distances from the query along specified dimension 
   local function distancesDimension(dimensionName)
      local vp, verboseLevel = makeVp(1, 'distancesDimension')
      vp(1, 'dimensionName', dimensionName)
      local distancesDimension = torch.Tensor(nSamples):fill(math.huge)
      for index, squaredDistance in pairs(nearestMaxK[dimensionName]) do
         vp(2, 'index', index, 'squaredDistance', squaredDistance)
         distancesDimension[index] = squaredDistance
      end

      vp(1, 'distancesDimension', distancesDimension)
      if verboseLevel > 0 then 
         printFiniteValues('distancesDimensions(' .. dimensionName .. ')', distancesDimension)
      end

      return distancesDimension
   end

   -- all distances, including those where feature is not present
   -- distances here are the squared distances
   local distancesSquared = 
     distancesDimension('latitude') + 
     distancesDimension('longitude') + 
     (distancesDimension('year') * (mPerYear * mPerYear))
   vp(2, 'distancesSquared', distancesSquared)
   
   -- keep only distances where feature is present
   -- discard a distance by setting it to infinity
   local sampleIndex = 0
   local function setHugeIfNaN(value)
      sampleIndex = sampleIndex + 1
      if isnan(value) then
         distancesSquared[sampleIndex] = math.huge
      end
   end

   vp(2, 'featureName', featureName)
   tensorViewColumn(features.t, features:columnIndex(featureName)):apply(setHugeIfNaN)

   -- determine count == number of non-infinite distances
   -- NOTE: count can be less than k
   local count = 0
   local function countNotInfinite(value)
      if value ~= math.huge then
         count = count + 1
      end
   end

   distancesSquared:apply(countNotInfinite)

   local sorted, indices = torch.sort(distancesSquared:sqrt())
   vp(1, 'sorted', sorted, 'indices', indices, 'count', count)
   local n = math.min(k, count)
   local indicesPrefix = tensorViewPrefix(indices, n)
   local sortedPrefix = tensorViewPrefix(sorted, n)
   vp(1, 'n', n, 'indicesPrefix', indicesPrefix, 'sortedPrefix', sortedPrefix)
   return n, indicesPrefix, sortedPrefix
end
