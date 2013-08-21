-- NnwEstimatorKwavg.lua
-- estimate value using kernel-weighted average of k nearest neighbors

-- API overview
if false then
   ekwavg = EstimatorKwAvg(xs, ys)

   -- when estimating a brand new query and hence not using the cache
   ok, estimate = ekwavg:estimate(query, k)
end -- API overview


--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

local _, parent = torch.class('NnwEstimatorKwavg', 'NnwEstimator')

function NnwEstimatorKwavg:__init(xs, ys, kernelName)
   local v, isVerbose = makeVerbose(true, 'NnwEstimatorKwavg:__init')
   assert(kernelName == 'epanechnikov quadratic',
          'only kernel supported is epanechnikov quadratic')   
   parent.__init(self, xs, ys)
end -- __init()

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function NnwEstimatorKwavg:estimate(query, k)
   -- estimate y for a new query point using the Euclidean distance
   -- ARGS:
   -- query          : 1D Tensor
   -- k              : integer > 0, number of neighbors
   -- RESULTS:
   -- true, estimate : estimate is the estimate for the query
   --                  estimate is a number
   -- false, reason  : no estimate was produced
   --                  reason is a string explaining why

   local v, isVerbose = makeVerbose(false, 'NnwEstimatorKwavg:estimate')
   verify(v, isVerbose,
          {{query, 'query', 'isTensor1D'},
           {k, 'k', 'isIntegerPositive'}})


   local sortedDistances, sortedNeighborIndices = Nnw.nearest(self._xs,
                                                              query)
   v('sortedDistances', sortedDistances)
   v('sortedNeighborIndices', sortedNeighborIndices)
   
   local lambda = sortedDistances[k]
   local weights = Nnw.weights(sortedDistances, lambda)
   v('lambda', lambda)
   v('weights', weights)

   local visible = torch.Tensor(self._ys:size(1)):fill(1)
   local ok, estimate = Nnw.estimateKwavg(k,
                                          sortedNeighborIndices,
                                          visible,
                                          weights,
                                          self._ys)
   v('ok,estimate', ok, estimate)
   return ok, estimate
end -- estimate()

--------------------------------------------------------------------------------
-- PRIVATE METHODS (NONE)
--------------------------------------------------------------------------------
