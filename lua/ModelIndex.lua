-- ModelIndex.lua
-- translate global observation numbers into fold-specific model numbers

-- API overview
if false then
   mi = ModelIndex(kappa)

   modelIndex = mi:globalToFold(globalIndex)
   globalIndex = mi:foldToGlobal(foldForModel, modelIndex)
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('ModelIndex')

function ModelIndex:__init(kappa)
   -- kappa       : sequence of fold numbers
   --               each fold number is an integer > 0
   local v = makeVerbose(false, 'ModelIndex:__init')
   v('kappa', kappa)
   affirm.isSequence(kappa, 'kappa')

   self._modelIndex = self:_makeTable(kappa)
   self._kappa = kappa
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function ModelIndex:foldToGlobal(foldNumber, localIndex)
   -- return global observation index that corresponds to the localIndex
   -- with the fold
   -- NOTE: The implementation is slow, as this method is used only
   -- for debugging for now
   -- ARGS
   -- foldNumber : integer > 0, fold number of the locaIndex
   -- localIndex : integer > 0, obs number within the fold
   -- RETURNS
   -- globalIndex : integer > 0 such that
   --               localIndex = self:globalToFold(kappa, globalIndex)
   local v = makeVerbose(false, 'ModelIndex:foldToGlobal')
   v('foldNumber', foldNumber)
   v('localIndex', localIndex)
   
   -- implementation is a sequential search through all possible global indices
   for i = 1, #self._kappa do
      if foldNumber == self._kappa[i] and localIndex == self:globalToFold(i)
      then return i
      end
   end

   error('cannot be here; foldNumber = ' .. 
         tostring(foldNumber) ..
         ' localIndex = ' .. tostring(localIndex))
end -- foldToGlobal

function ModelIndex:globalToFold(globalIndex)
   -- return the index into observations for fold kappa[globalIndex] of 
   -- observation with the globalIndex
   -- ARGS
   -- globalIndex : integer > 0
   --               the index of an observation
   local v = makeVerbose(false, 'ModelINdex:globalToFold')

   -- kappa is type checked in _makeTable
   affirm.isIntegerPositive(globalIndex, 'globalIndex')

   return self._modelIndex[globalIndex]
end -- globalToFold

--------------------------------------------------------------------------------
-- PRIVATE METHODS
--------------------------------------------------------------------------------

function ModelIndex:_makeTable(kappa)
   -- return modelIndex table such that
   --    modelIndex[i] is the local observation index of global obs index i
   local v = makeVerbose(false, 'ModelIndex:_makeTable')
   v('kappa', kappa)
   affirm.isSequence(kappa, 'kappa')

   -- determine number of folds
   nFolds = 1
   for i = 1, #kappa do
      local foldNumber = kappa[i]
      affirm.isIntegerPositive(foldNumber, 'foldNumber')
      nFolds = math.max(nFolds, foldNumber)
   end

   lastIndex = {}
   for foldNumber = 1, nFolds do
      lastIndex[foldNumber] = 0
   end

   modelIndex = {}
   for i = 1, #kappa do
      local foldNumber = kappa[i]
      lastIndex[foldNumber] = lastIndex[foldNumber] + 1
      modelIndex[i] = lastIndex[foldNumber]
   end
   
   v('modelIndex', modelIndex)
   return modelIndex
end -- _makeTable