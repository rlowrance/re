-- knn_implementation_2.lua
-- compute nearest neighbors with known features and varying mPerYear via table of knn functions
-- 
-- This implementation is approximate in determining the nearest neighbors.
--
-- Set maxK based on the size of RAM
-- . Each space and time table has 3 tensors
-- . Each such tensor has maxK elements of 4 byte each
-- . So each knnInfo table has 6 * 4 * maxK bytes
-- . We need 1.2 million such tables
--
-- knn.knnInfo(queryIndex, features, maxK, dSpace2Fn, dTime2Fn)   --> knnInfo table
-- knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)  --> n, indices (in features), distances
--
--
-- with types
--   queryIndex           : positive integer, row number in features
--   features             : NamedMatrix withk rows = samples and columns = features
--   maxK                 : positive integer
--   dSpace2Fn            : function(features, queryIndex) --> Float 1DTensor of squared spatial distances
--                          from sample at queryIndex to every other sample
--   dTimee2Fn            : function(features, queryIndex) --> Float 1DTensor of squared temporal distances
--                          from sample at queryIndex to every other sample
--   k                    : positive integer <= maxK
--   mPerYear             : number of meters in one year of distance
--   knnInfo              : opaque table with info on the maxK neighbors of a specific queryIndex in features
--   n                    : 0 <= integer <= k, number of neighbors with known feature values found
--   indices              : sample numbers in original features
--   distances            : spatio-temporal squared distances from query point to index samples in features
--
-- knnInfo contains these fields with distances along the specified dimensions
-- .space                 : table with 3 subtables
--                          .index   : IntTensor of indices of maxK nearest neighbors in space dimension
--                          .dSpace2 : Tensor of distance^2 in space dimension for corresonding indices
--                          .dTime2  : Tensor of distance^2 in time dimension for corresponding indices
-- .time                  : table similar to space table
--
-- NOTE: a 32-bit int can hold a number up to about 2 billion

knn = {}

require 'makeVp'
require 'tensorViewColumn'
require 'tensorViewPrefix'
require 'pp'

function pp.knnInfo(value)
   -- print knnInfo nicely
   local maxK = value.space.index:size(1)
   print('knnInfo')
   print('space                         time')
   print('  index   space^2    time^2    index   space^2    time^2')
   for i = 1, maxK do
      print(string.format('%7d %9.4f %9.4f  %7d %9.4f %9.4f', 
            value.space.index[i], value.space.dSpace2[i], value.space.dTime2[i],
            value.time.index[i], value.time.dSpace2[i], value.time.dTime2[i]))
   end
end

-- return knnInfo table
function knn.knnInfo(queryIndex, features, maxK, dSpace2Fn, dTime2Fn)
   local distanceSpace2 = dSpace2Fn(features, queryIndex)
   local distanceTime2 = dTime2Fn(features, queryIndex)

   local sorted, indices = torch.sort(distanceSpace2)
   local firstIndices = tensor.viewPrefix(indices, maxK)
   local space = {
      index = firstIndices,
      dSpace2 = tensor.viewPrefix(sorted, maxK),
      dTime2 = tensor.selected(distanceTime2, firstIndices),
   }

   local sorted, indices = torch.sort(distanceTime2)
   local firstIndices = tensor.viewPrefix(indices, maxK)
   local time = {
      index = firstIndices,
      dSpace2 = tensor.selected(distanceSpace2, firstIndices),
      dTime2 = tensor.viewPrefix(sorted, maxK),
   }

   local result = {
      space = space,
      time = time,
   }

   return result
end

-- return up to k indices (in features), squared distances (corresponding to indices)
-- NOTE: may return less than k nearest neighbors
-- knn.nearestKnown(knnInfo, k, mPerYear, features, featureName) 
function knn.nearestKnown(knnInfo, k, mPerYear, features, featureName)
   local debug = false

   local maxK = knnInfo.space.index:size(1)

   -- merge the indices and distances in the space and time dimensions
   local mergedIndices = torch.IntTensor(2 * maxK):fill(0)
   local mergedDistances2 = torch.FloatTensor(2 * maxK):fill(math.huge)
   
   local mPerYear2 = mPerYear * mPerYear

   local presentInSpace = {}
   local space = knnInfo.space
   for i = 1, maxK do
      local spaceIndex = space.index[i]
      presentInSpace[spaceIndex] = true
      mergedIndices[i] = spaceIndex
      mergedDistances2[i] = space.dSpace2[i] + space.dTime2[i] * mPerYear2
   end

   local nextMergedIndex = maxK
   local time = knnInfo.time
   for i = 1, maxK do
      timeIndex = time.index[i]
      if not presentInSpace[timeIndex] then
         nextMergedIndex = nextMergedIndex + 1
         mergedIndices[nextMergedIndex] = timeIndex
         mergedDistances2[nextMergedIndex] = time.dSpace2[i] + time.dTime2[i] * mPerYear2
      end
   end

   if debug then
      pp.knnInfo(knnInfo)
      print('merged')
      for i = 1, 2 * maxK do
         print(string.format('%3d %9.4f', mergedIndices[i], mergedDistances2[i]))
      end
   end



   local sortedDistances, sortedIndices = torch.sort(mergedDistances2)
   if debug then
      print('sorted')
      for i = 1, 2 * maxK do
         print(string.format('%3d %9.4f', mergedIndices[sortedIndices[i]], sortedDistances[i]))
      end
   end

   local featureNameColumn = features:columnIndex(featureName)
   local found = 0
   local resultIndices = torch.Tensor(k)
   local resultDistances = torch.Tensor(k)
   for i = 1, maxK * 2 do
      local distance = sortedDistances[i]
      if distance == math.huge then
         -- stop at first infinite value
         break
      end

      local sampleIndex = mergedIndices[sortedIndices[i]]
      if not isnan(features.t[sampleIndex][featureNameColumn]) then
         found = found + 1
         resultIndices[found] = sampleIndex
         resultDistances[found] = distance
         if found == k then
            break
         end
      elseif debug then
         print(string.format('missing feature in sample %d', sampleIndex))
      end
   end

   if debug then
      print('results')
      for i = 1, k  do
         print(string.format('%3d %9.4f', resultIndices[i], resultDistances[i]))
      end
   end

   local resultIndices = tensor.viewPrefix(resultIndices, found)
   local resultDistances = tensor.viewPrefix(resultDistances, found)

   return found, resultIndices, resultDistances -- NOTE: distances are squared
end
