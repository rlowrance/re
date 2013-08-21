-- DiagonalMatrix.lua

require 'makeVerbose'
require 'verify'

-- API overview
if false then
   dm = DiagonalMatrix(vector)

   matrixResult = dm:mul(matrix)  -- return dm * A as matrix multiplication
   vectorResult = dm:mul(vector)  -- return dot product
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('DiagonalMatrix')

function DiagonalMatrix:__init(t)
   local v, isVerbose = makeVerbose(false, 'DiagonalMatrix:__init')
   verify(v, isVerbose,
          {{t, 't', 'isTensor1D'}})
   self._t = t
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function DiagonalMatrix:mul(t)
   local v, isVerbose = makeVerbose(false, 'DiagonalMatrix:mul')
   verify(v, isVerbose,
          {{t, 't', 'isTensor'}})

   local d = t:nDimension()
   if d == 1 then
      return self:_mulVector(t)
   elseif d == 2 then
      return self:_mulMatrix(t)
   else
      error('only 1D and 2D tensors are allows; t = ' .. tostring(t))
   end
end -- mul

--------------------------------------------------------------------------------
-- PRIVATE METHODS
--------------------------------------------------------------------------------

function DiagonalMatrix:_mulMatrix(matrix)
   local v, isVerbose = makeVerbose(false, 'DiagonalMatrix:_mulMatrix')
   verify(v, isVerbose,
          {{matrix, 'matrix', 'isTensor2D'}})
   assert(self._t:size(1) == matrix:size(1))
   
   -- (result)_{ij} = \sum_k t_{ik} matrix_{kj} = t_{ii} matrix_{ij}

   local result = matrix:clone()
   for i = 1, self._t:size(1) do
      for j = 1, matrix:size(2) do
         result[i][j] = result[i][j] * self._t[i]
      end
   end
   
   return result
end -- _mulMatrix

function DiagonalMatrix:_mulVector(vector)
   local v, isVerbose = makeVerbose(false, 'DiagonalMatrix:_mulVector')
   verify(v, isVerbose,
          {{vector, 'vector', 'isTensor1D'}})
   assert(self._t:size(1) == vector:size(1))
   
   -- (result)_{ij} = \sum_k t_{ik} matrix_{kj} = t_{ii} matrix_{ij}

   local result = vector:clone()
   for i = 1, self._t:size(1) do
      result[i] = result[i] * self._t[i]
   end
   
   return result
end -- _mulVector
