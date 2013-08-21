-- Nncache.lua
-- nearest neighbors cache

-- API overview
if false then
   -- construction
   nnc = Nncache() 

   -- setter and getter
   nnc:setLine(obsIndex, tensor1D)
   tensor1D = nnc:getLine(obsIndex)  -- may return null

   -- apply a function to each key-value pair
   local function f(key,value)
   end
   
   nnc:apply(f)

    -- saving to a file and restoring from one
   -- the suffix is determined by the class Nncachebuilder
   nnc:save(filePath)
   nnc = nnc.load(filePath)
   nnc = nnc.loadUsingPrefix(filePathPrefix)
end


--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('Nncache')

function Nncache:__init()
   self._table = {}
   self._lastValuesSize = nil
end

--------------------------------------------------------------------------------
-- PUBLIC CLASS METHODS
--------------------------------------------------------------------------------

function Nncache.load(filePath)
   -- return an nnc; error if there is no saved Nncache at the filePath
   local v, isVerbose = makeVerbose(true, 'Nncache.load')
   verify(v, isVerbose,
          {{filePath, 'filePath', 'isString'}})
   local nnc = torch.load(filePath,
                          Nncachebuilder.format())
   --v('nnc', nnc)
   v('typename', torch.typename(nnc))
   assert(torch.typename(nnc) == 'Nncache',
          'bad typename  = ' .. tostring(torch.typename(nnc)))
   -- NOTE: cannot test if each table entry has 256 rows, because the
   -- original allXs may have had fewer than 256 observations
   return nnc
end -- read

function Nncache.loadUsingPrefix(filePathPrefix)
   return Nncache.load(Nncache._filePath(filePathPrefix))
end -- loadUsingPrefix

--------------------------------------------------------------------------------
-- PRIVATE CLASS METHODS
--------------------------------------------------------------------------------

function Nncache._filePath(filePathPrefix)
   return filePathPrefix .. Nncachebuilder.mergedFileSuffix()
end -- _filePath

--------------------------------------------------------------------------------
-- PUBLIC INSTANCE METHODS
--------------------------------------------------------------------------------

function Nncache:apply(f)
   -- apply a function to each key-value pair
   for key, value in pairs(self._table) do
      f(key, value)
   end
end -- apply
                       
function Nncache:getLine(obsIndex)
   -- return line at key or null
   local v, isVerbose = makeVerbose(false, 'Nncache:getline')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'}})

   return self._table[obsIndex]
end -- getline

function Nncache:setLine(obsIndex, values)
   -- set the line, checking that it is not already set
   local v, isVerbose = makeVerbose(false, 'Nncache:setLine')
   verify(v, isVerbose,
          {{obsIndex, 'obsIndex', 'isIntegerPositive'},
           {values, 'values', 'isTensor1D'}})

   v('self', self)

   -- check that size of values is same on every call
   if self._lastValuesSize then
      local newSize = values:size(1)
      assert(self._lastValuesSize == newSize,
             string.format('cannot change size of values; \n was %s; \n is %s',
                           tostring(self._lastValuesSize),
                           tostring(newSize)))
      self._lastValuesSize = newSize
   else
      self._lastValuesSize = values:size(1)
   end

   -- check that the obsIndex slot has not already been filled
   assert(self._table[obsIndex] == nil,
          string.format('attempt to set cache line already filled; \nobsIndex ',
                        tostring(obsIndex)))
   self._table[obsIndex] = values
end -- setLine

function Nncache:save(filePath)
   -- write to disk by serializing
   -- NOTE: if the name of this method were 'write', then the call below
   -- to torch.save would call this function recursively. Hence the name
   -- of this function.
   local v, isVerbose = makeVerbose(false, 'Nncache:write')
   v('self', self)
   verify(v, isVerbose,
          {{filePath, 'filePath', 'isString'}})

   v('filePath', filePath)
   v('Nncachebuilder.format()', Nncachebuilder.format())
   torch.save(filePath, self, Nncachebuilder.format())
end -- write