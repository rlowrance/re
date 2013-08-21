-- Nncachebuilder.lua
-- cache for nearsest 256 neighbors

-- API overview
if false then
   nncb = Nncachebuilder(allXs, nShards)
   for n = 1, nShards do
      -- serialize cache object (a table) to file <prefix>nncache-shard-n.txt
      nncb:createShard(n, 'filePathPrefix')
   end
   -- create serialized cache object int file <prefix>nncache-merged.txt
   Nncachebulder.mergeShards(nShards, 'filePathPrefix')

   -- ILLUSTRATIVE USE

   -- read the serialized merged cache from file system
   cache = Nncache.loadUsingPrefix('filePathPrefix') 
   -- now cache[27] is a 1D tensor of the sorted indices closest to obs # 27
   -- in the original xs
   
   -- use the cache to smooth values
   selected = setSelected() -- to selected observations in Xs and Ys
   -- use the original allXs to create smoothed estimates
   knnSmoother = KnnSmoother(allXs, allYs, selected, cache)
   estimate = knnSmoother:estimate(queryIndex, k)
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('Nncachebuilder')

function Nncachebuilder:__init(allXs, nShards)
   local v, isVerbose = makeVerbose(false, 'Nncachebuilder:__init')
   verify(v, isVerbose,
          {{allXs, 'allXs', 'isTensor2D'},
           {nShards, 'nShards', 'isIntegerPositive'}})
   -- an index must fit into an integer
   assert(allXs:size(1) <= 2147483647,  -- about 2 billion
          'more than 2^31 - 1 rows in the tensor')
   self._allXs = allXs
   self._nShards = nShards
   self._cache = Nncache()

end -- __init

--------------------------------------------------------------------------------
-- PUBLIC CLASS METHODS
--------------------------------------------------------------------------------

function Nncachebuilder.format()
   -- format used to serialize the cache
   return 'ascii' -- 'binary' is faster
end -- _format

function Nncachebuilder.maxNeighbors()
   -- number of neighbor indices stored; size of cache[index]
   return 256
end

function Nncachebuilder.mergedFileSuffix()
   -- end part of file name
   return 'nncache-merged.txt'
end -- mergedFileSuffix

--------------------------------------------------------------------------------
-- PRIVATE CLASS METHODS
--------------------------------------------------------------------------------

function Nncachebuilder._shardFilePath(filePathPrefix, shardNumber)
   return filePathPrefix .. string.format('shard-%d.txt', shardNumber)
end -- _shardFilePath

--------------------------------------------------------------------------------
-- PUBLIC INSTANCE METHODS
--------------------------------------------------------------------------------

function Nncachebuilder:createShard(shardNumber, filePathPrefix, chatty)
   -- create an Nncache holding all the nearest neighbors in the shard
   -- write this Nncache to disk
   -- return file path where written
   local v, isVerbose = makeVerbose(false, 'createShard')
   verify(v, isVerbose,
          {{shardNumber, 'shardNumber', 'isIntegerPositive'},
           {filePathPrefix, 'filePathPrefix', 'isString'}})
   -- set default for chatty [true]
   v('chatty', chatty)
   if chatty == nil then
      chatty = true
   end
   v('chatty', chatty)
   
   v('self', self)
   assert(shardNumber <= self._nShards)

   local tc = TimerCpu()
   local cache = Nncache()
   local count = 0
   local shard = 0
   local roughCount = self._allXs:size(1) / self._nShards
   for obsIndex = 1, self._allXs:size(1) do
      shard = shard + 1
      if shard > self._nShards then
         shard = 1
      end
      if shard == shardNumber then
         -- observation in shard, so create its neighbors indices
         local query = self._allXs[obsIndex]:clone()
         collectgarbage()
         local _, allIndices = Nnw.nearest(self._allXs,
                                          query)
         -- NOTE: creating a view of the storage seems like a good idea
         -- but fails when the tensor is serialized out
         local n = math.min(Nncachebuilder.maxNeighbors(), self._allXs:size(1))
         local firstIndices = torch.Tensor(n)
         for i = 1, n do
            firstIndices[i] = allIndices[i]
         end
         cache:setLine(obsIndex, firstIndices)
         count = count + 1
         if false then 
            v('count', count)
            v('obsIndex', obsIndex)
            v('firstIndices', firstIndices)
         end
         if count % 10000 == 1 and chatty then
            local rate = tc:cumSeconds() / count
            print(string.format(
                     'Nncachebuilder:createShard: create %d indices' ..
                        ' at %f CPU sec each',
                     count, rate))
            local remaining = roughCount - count
            print(string.format('need %f CPU hours to finish remaining %d',
                                rate * remaining / 60 / 60, remaining))
            --halt()
         end
      end
   end
   v('count', count)
   -- halt()

   -- write by serializing
   local filePath = Nncachebuilder._shardFilePath(filePathPrefix, shardNumber)
   v('filePath', filePath)
   cache:save(filePath)
   return filePath
end -- createShard


function Nncachebuilder.mergeShards(nShards, filePathPrefix, chatty)
   -- RETURN
   -- number of records in merged file
   -- file path where merged cache data were written
   local v, isVerbose = makeVerbose(false, 'mergeShards')
   verify(v, isVerbose,
          {{nShards, 'nShards', 'isIntegerPositive'},
           {filePathPrefix, 'filePathPrefix', 'isString'}})

   -- set default for chatty [true]
   if chatty == nil then
      chatty = true
   end

   local cache = Nncache()
   local countAll = 0
   for n = 1, nShards do
      local path = Nncachebuilder._shardFilePath(filePathPrefix, n)
      if chatty then
         print('reading shard cache file ', path)
      end
      local shard = Nncache.load(path)
      affirm.isTable(shard, 'Nncache')

      -- insert all shard elements into the cache
      local countShard = 0
      local function insert(key, value)
         cache:setLine(key, value)
         countShard = countShard + 1
      end
      shard:apply(insert)
      if chatty then
         print('number records inserted from shard', countShard)
      end
   end
   if chatty then
      print('number of records inserted from all shards', countAll)
   end

   local mergedFilePath = filePathPrefix .. Nncachebuilder.mergedFileSuffix()
   if chatty then 
      print('writing merged cache file', mergedFilePath)
   end
   torch.save(mergedFilePath, cache, Nncachebuilder.format())
   return countAll, mergedFilePath
end -- mergeShards

