-- NnwSmootherAvg.lua
-- estimate value using simple average of k nearest neighbors

-- API overview
if false then
   sa = SmootherAverage(allXs, allYs, visible, cache)
   ok, estimate = sa:estimate(queryIndex, k)
end -- API overview

--------------------------------------------------------------------------------
-- NnwSmootherAvg
--------------------------------------------------------------------------------

local _, parent = torch.class('NnwSmootherAvg', 'NnwSmoother')

function NnwSmootherAvg:__init(allXs, allYs, visible, nncache) 
   local v, isVerbose = makeVerbose(false, 'NnwSmootherAvg:__init')
   parent.__init(self, allXs, allYs, visible, nncache)
   v('self', self)
end -- __init()


function NnwSmootherAvg:estimate(obsIndex, k)
   local v, isVerbose = makeVerbose(false, 'NnwSmootherAvg:estimate')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'},
           {k, 'k', 'isIntegerPositive'}})
   
   assert(k <= Nncachebuilder:maxNeighbors())

   v('self._nncache', self._nncache)
   local nearestIndices = self._nncache:getLine(obsIndex)
   assert(nearestIndices)
   v('nearestIndices', nearestIndices)
   v('self._visible', self._visible)
   v('self', self)

   local ok, result = Nnw.estimateAvg(self._allXs,
                                      self._allYs,
                                      nearestIndices, 
                                      self._visible,
                                      k)
   --halt()
   return ok, result
end -- estimate
