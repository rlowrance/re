-- makeCachedNnIndicesFunction.lua
-- return a nnIndicesFunction designed to work with a cache

require 'Validations'

-- sort pairs by distance component, the 1st component
local function aComesBeforeB(a, b)
   return a[1] < b[1]
end

-- return indices of nearest k neighbors
function nearesKIndices(query, k, distanceFunction, inputs)
   -- determine distance-index pairs from query to each element of training set
   local distances = {}
   for i, x in ipairs(inputs) do
      distances[#distances + 1] = {distanceFunction(query, x), i}
   end
   
   table.sort(distances, aComesBeforeB) -- 

   -- return first k entries, which are the k closest
   local result = {}
   for i=1,k do
      result[#result + 1] = distances[i][2]
      --print('defaultNnIndicesFunction nextIndex', distances[i][2])
   end

   return result
end

-- return indices of nearest 256 neighbors
function nearest256Indices(queryIndex, distanceFunction, inputs)
   local query = inputs[queryIndex]
   assert(query, queryIndex)
   return nearestKIndices(query, 256, distanceFunction, inputs)
end

-- make function to enable caching of KNN neighbors
-- + cacheFilePath : string, path to the cache file
-- return
-- + nnIndicesFunction(query, k, distanceFunction, input) --> array of indices
--   returns the indices
-- + nnCacheWriteFunction() --> nil
--   write the cache file which may have been built up through calls to 
--   nnIndicesFunction
function makeCachedNnIndicesFunction(cacheFilePath)
   Validations.isNotNil(cacheFilePath)

   -- read the cache file, create cache
   local cache = {} -- key = index, value = array of 256 nearest neighbors
   function c(key, values)
      cache[key] = values
   end
   -- cache file format is
   -- c(20, {12, 14, 87, 93, ...}}
   dofile(cacheFilePath)

   
   -- construct the two functions that are the return values
   function nnIndices(query, k, distanceFunction, inputs)
      Validations.isTensor(query, 'query')
      Validations.isNumberLe(k, #inputs, 'k', 'number of inputs')
      Validations.isFunction(distanceFunction, 'distanceFunction')
      Validations.isTable(inputs, 'inputs')

      local queryIndex = getQueryIndex(query, inputs)
      if queryIndex ~= 0 then
         -- query is in inputs, so use the cache
         local values = cache[queryIndex]
         if not values then
            values = nearest256Indices(queryIndex, distanceFunction, inputs)
            cache[queryIndex] = values
         end
         -- return the first k values
         local result = {}
         for i=1,k do
            result[#result + 1] = values[k]
         end
         return result
      else
         return nearestKIndices(query, k, distanceFunction, inputs)
      end
   end

   function appendToFileCache()
      local cacheFile = io.open(cacheFilePath, 'a+') -- append update mode
      for k, values in cache do 
         write('c(')
         write(k)
         write(',{')
         for _,value in pairs(values) do
            write(value)
            write(',')
         end
         write('})\n')
      end
   end
      

   return nnIndices, appendToFileCache
end
      