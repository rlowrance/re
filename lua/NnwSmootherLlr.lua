-- NnwSmootherLlr.lua
-- estimate value using kernel-weighted average of k nearest neighbors

-- API overview
if false then
   skwavg = NnwSmootherLlr(allXs, allYs, visible, cache)
   ok, estimate = skwavg:estimate(queryIndex, k)
end -- API overview


--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

local _, parent = torch.class('NnwSmootherLlr', 'NnwSmoother')

function NnwSmootherLlr:__init(allXs, allYs, visible, nncache, kernelName)
   local v, isVerbose = makeVerbose(false, 'NnwSmootherLlr:__init')
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

function NnwSmootherLlr:estimate(obsIndex, params)
   local v, isVerbose = makeVerbose(false, 'NnwSmootherLlr:estimate')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'},
           {params, 'params', 'isTable'}})
   v('self', self)

   affirm.isIntegerPositive(params.k, 'params.k')
   affirm.isNumberNonNegative(params.regularizer, 'params.regularizer')

   local k = params.k

   local maxNeighbors = Nncachebuilder:maxNeighbors()
   assert(k <= maxNeighbors,
	  string.format('k (=%d) exceeds pre-built max number of neighbors (=%d)',
			k, maxNeighbors))

   -- determine distances and lambda
   -- NOTE: code is the same as in SmootherKwavg:estimate
   local nObs = self._visible:size(1)
   local distances = torch.Tensor(nObs):fill(1e100)
   local query = self._allXs[obsIndex]
   v('query', query)
   local sortedNeighborIndices = self._nncache:getLine(obsIndex)
   assert(sortedNeighborIndices)
   v('sortedNeighborIndices', sortedNeighborIndices)
   local nSortedNeighborIndices = sortedNeighborIndices:size(1)
   local found = 0
   for i = 1, nObs do
      assert(i <= nSortedNeighborIndices,
	     string.format(
		'have not found k (=%d) neighbors in %d sortedNeighborIndices',
		k, nSortedNeighborIndices))	   
      local obsIndex = sortedNeighborIndices[i]
      v('i, obsIndex', i, obsIndex)
      if self._visible[obsIndex] == 1 then
         local distance= Nnw.euclideanDistance(self._allXs[obsIndex], query)
         distances[i] = distance
         if debug == 1 then
            v('x', self._allXs[obsIndex])
         end
         v('i,obsIndex,distance', i, obsIndex, distance)
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

   local ok, estimate = Nnw.estimateLlr(k,
                                        params.regularizer,
                                        sortedNeighborIndices,
                                        self._visible,
                                        weights,
                                        self._allXs[obsIndex]:clone(),
                                        self._allXs,
                                        self._allYs)
   v('ok, estimate', ok, estimate)
   return ok, estimate 
end -- estimate



