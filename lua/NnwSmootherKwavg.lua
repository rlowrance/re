-- NnwSmootherKwavg.lua
-- estimate value using kernel-weighted average of k nearest neighbors

-- API overview
if false then
   skwavg = NnwSmootherKwavg(allXs, allYs, visible, cache)
   ok, estimate = skwavg:estimate(queryIndex, k)
end -- API overview


--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

local _, parent = torch.class('NnwSmootherKwavg', 'NnwSmoother')

function NnwSmootherKwavg:__init(allXs, allYs, visible, nncache, kernelName)
   local v, isVerbose = makeVerbose(false, 'NnwSmootherKwavg:__init')
   verify(v, isVerbose,
          {{allXs, 'allXs', 'isTensor2D'},
           {allYs, 'allYs', 'isTensor1D'},
           {visible, 'visible', 'isTensor1D'},
           {nncache, 'nncache', 'isTable'}})
   assert(kernelName == 'epanechnikov quadratic',
          'only kernel supported is epanechnikov quadratic')
   assert(torch.typename(nncache) == 'Nncache')
   parent.__init(self, allXs, allYs, visible, nncache)
   v('self', self)
   v('self._nncache', self._nncache)
end -- __init()

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function NnwSmootherKwavg:estimate(obsIndex, k)
   local debug = 0
   debug = 4 -- zero value for lambda
   local version = 'both' -- 'self contained', 'use nnw', or 'both'
   local v, isVerbose = makeVerbose(true, 'NnwSmootherKwavg:estimate')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'},
           {k, 'k', 'isIntegerPositive'}})
   v('self', self)
   assert(k <= Nncachebuilder:maxNeighbors())

   -- determine distances and lambda
   local nObs = self._visible:size(1)
   local distances = torch.Tensor(nObs):fill(1e100)
   local query = self._allXs[obsIndex]
   v('query', query)
   local sortedNeighborIndices = self._nncache:getLine(obsIndex)
   assert(sortedNeighborIndices)
   v('sortedNeighborIndices', sortedNeighborIndices)

   local okSelfContained
   local estimateSelfContained
   if version == 'self-contained' or version == 'both' then
      local found = 0
      for i = 1, nObs do
         local obsIndex = sortedNeighborIndices[i]
         if self._visible[obsIndex] == 1 then
            local x = self._allXs[obsIndex]
            local distance= Nnw.euclideanDistance(x, query)
            distances[i] = distance
            v('x', x)
            v('i,obsIndex,distance', i, obsIndex, distance)
            if debug == 4 then
               -- check if query and x are identifical
               assert(query:size(1) == query:size(2))
               local allSame = true
               for d = 1, query:size(1) do
                  if query[d] ~= x[d] then
                     allSame = false
                     print('differ')
                     print('d', d)
                     print('query[d]', query[d])
                     print('x[d]', x[d])
                  end
               end
               print('allSame', allSame)
               halt()
            end
            found = found + 1
            if found == k then
               lambda = distance
               break
            end
         end
      end
      v('lambda', lambda)
      v('distances', distances)
      
      if lambda == 0 then
      return false, 'lambda == 0'
      end
      
      local weights = Nnw.weights(distances, lambda)
      v('weights', weights)
      
      okSelfContained, estimateSelfContained = 
         Nnw.estimateKwavg(k,
                           sortedNeighborIndices,
                           self._visible,
                           weights,
                           self._allYs)
      v('okSelfContained, estimateSelfContained', 
        okSelfContained, estimateSelfContained)
   end
   
   local okUseNnw
   local estimateUseNnw
   if version == 'use nnw' or version == 'both' then
      okUseNnw, estimateUseNnw = Nnw.estimateKwavg(k,
                                                   sortedNeighborIndices,
                                                   visible,
                                                   weights,
                                                   self._ys)
      v('okUseNnw,estimateUseNnw', okUseNnw, estimateUseNnw)
   end

   -- check for same answer if ran both versions
   if version == 'both' then
      assert(okSelfContained == okUseNnw)
      assert(estimateSelfContained == estimateUseNnw)
   end

   -- return one of the answers
   if estimateSelfContained then
      return okSelfContained, estimateSelfContained
   else
      return okUseNnw, estimateUseNnw
   end
end -- estimate



