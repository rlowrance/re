-- NnwSmoother.lua
-- parent class for all NnwSmoother classes

require 'affirm'
require 'makeVerbose'
require 'verify'

-- API overview
if false then
   s = NnwSmoother(allXs, allYs, visible, cache)

   -- all methods are supplied by a subclass
end -- API overview

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('NnwSmoother')

function NnwSmoother:__init(allXs, allYs, visible, nncache) 
   -- ARGS:
   -- xs            : 2D Tensor
   --                 the i-th input sample is xs[i]
   -- ys            : 1D Tensor
   --                 y[i] is the known value (target) of input sample xs[i]
   --                 number of ys must equal number of rows in xs 
   -- visible       : 1D tensor of {0,1} values
   --                 the only values used have visible[i] == 1
   -- nncache       : Nncache object
   --                 nncache[obsIndex] = 1D tensor of indices in allXs of
   --                 256 nearest neighbors to allXs[obsIndex]

   local v, isVerbose = makeVerbose(false, 'NnwSmoother:__init')
   verify(v, 
          isVerbose,
          {{allXs, 'allXs', 'isTensor2D'},
           {allYs, 'allYs', 'isTensor1D'},
           {visible, 'visible', 'isTensor1D'},
           {nncache, 'nncache', 'isNotNil'}})
   assert(torch.typename(nncache) == 'Nncache')
   local nObs = allXs:size(1)
   assert(nObs == allYs:size(1))
   assert(nObs == visible:size(1))

   -- check that visible is correctly structured
   for i = 1, visible:size(1) do
      local value = visible[i]
      affirm.isIntegerNonNegative(value, 'value')
      assert(value <= nObs)
      assert(value == 0 or value == 1)
   end
   
   self._allXs = allXs
   self._allYs = allYs
   self._visible = visible
   self._nncache = nncache

   self._kMax = Nncachebuilder.maxNeighbors()
end -- NnNnwSmoother:__init()

--------------------------------------------------------------------------------
-- PUBLIC METHODS 
--------------------------------------------------------------------------------

function NnwSmoother:makeWeightsDEAD(obsIndex, k)
   -- return the kernelized weights for allXs[obsIndex] with k nearest neighbors
   local v, isVerbose = makeVerbose(false, 'NnwSmootherKwavg:makeWeights')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'},
           {k, 'k', 'isIntegerPositive'}})
   
   assert(k <= Nncachebuilder:maxNeighbors())
   
   -- determine sortedDistances and lambda without call Nn.nearest
   -- use the pre-computed nearestIndices
   local nearestIndices = self._nncache:getLine(obsIndex)
   v('nearestIndices', nearestIndices)
   v('self._visible', self._visible)
   -- initialize sortedDistances to something very large, but not
   -- math.huge because in Nn.weights, one does
   --   inf * 0 which is NaN, not 0
   local sortedDistances = torch.Tensor(self._allYs:size(1)):fill(1e100)
   local found = 0
   local query = self._allXs[obsIndex]
   local lambda                     -- distance to k-th nearest neighbor
   for i = 1, nearestIndices:size(1) do
      local obsIndex = nearestIndices[i]
      if self._visible[obsIndex] == 1 then
         found = found + 1
         local distance = Nnw.euclideanDistance(self._allXs[obsIndex], query)
         sortedDistances[obsIndex] = distance
         v('obsIndex, found, distance', obsIndex, found, distance)
         if found == k then
            lambda = distance
            break
         end
      end
   end
       
   v('sortedDistances', sortedDistances)
   v('lambda', lambda)
   --halt()
   local weights = Nnw.weights(sortedDistances, lambda)
   v('weights')
   --halt()
   return weights
end -- makeWeights
