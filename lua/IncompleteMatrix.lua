-- IncompleteMatrix.lua
-- partially known matrix class

--require 'torch'

require 'optim'

require 'affirm'
require 'check'
require 'makeVerbose'
require 'shuffleSequence'
require 'sortedKeys'


-- API overview
if false then
   -- constructing
   im = IncompleteMatrix()
   clone = im:clone()         -- share-nothing copy

   -- adding entries
   im:add(i, j, 123.0)        -- return false if already in the im

   -- retrieving known entries
   x = im:get(rowIndex, colIndex) -- error if there is no such entry
   x = im:maybeGet(rowIndex, colIndex) -- return nil if no such entry

   -- determing sizes
   nrows = im:getNRows()
   ncols = im:getNColumns()
   n = im:getNElements()       -- number of sparse elements

   -- comparing for equality of known elements
   if im:self(otherIm) then return allElementsEqual end
   
   -- determining average value of known entries
   avgValue = im:averageValue()

   -- iterating over entries
   for rowIndex, colIndex, value in im:triples() do
      -- iterate over known entries
   end

   -- printing
   im:print()                 -- print all entries
   im:printHead()             -- print some entries to stdout

   -- reading and writing the entire instance
   -- Note: these are class methods, not instance methods
   IncompleteMatrix.serialize('path/to/file')
   im = IncompleteMatrix.deserialize('path/to/file')


end

-- create class object
local IncompleteMatrix = torch.class('IncompleteMatrix')

function IncompleteMatrix:__init(rowsOption, columnsOption)
   -- build known s.t. self.known[rowIndex][colIndex] == value or nil
   local v = makeVerbose(false, 'IncompleteMatrix:__init')
   v('rowsOption', rowsOption)
   v('colsOption', colsOption)

   -- initialize for no fixed bounds case
   self.known = {}      -- sparse sequence of sparse sequences

   self.nElements = 0       -- number known elements
   self.nColumns = 0
   self.nRows = 0
   self.fixedBounds = false

   if rowsOption ~= nil then
      -- initialize for fixed bounds case
      v('setting bounds')
      affirm.isIntegerPositive(rowsOption, 'rowsOption')
      affirm.isIntegerPositive(columnsOption, 'columnsOption')
      self.nRows = rowsOption
      self.nColumns = columnsOption
      self.fixedBounds = true
   end

   v('self', self)
end

function IncompleteMatrix:add(rowIndex, colIndex, value, verbose)
-- add entry
-- return true if added (it was not a duplicate)
-- return false if not added (it was a duplicate)
   local trace = false
   if verbose then trace = true end
   if trace then 
      print('IncompleteMatrix:add rowIndex, colIndex, value',
            rowIndex, colIndex, value)
   end
   local whetherToTestUpperBound = self.fixedBounds
   self:_checkIndices(rowIndex, colIndex, whetherToTestUpperBound)
   assert(value, 'value must not be nil')
   assert(type(value) == 'number', 'value must be a number')

   -- don't add for a second time
   if self.known[rowIndex] == nil then
      self.known[rowIndex] = {}
   end
   if self.known[rowIndex][colIndex] == nil then
      self.known[rowIndex][colIndex] = value
      self.nElements = self.nElements + 1
      if rowIndex > self.nRows then 
         self.nRows = rowIndex
      end
      if colIndex > self.nColumns then
         self.nColumns = colIndex
      end
      if trace then print(' added') end
      return true -- indicate element was added to the IncompleteMatrix
   else
      if trace then print(' not added, alread in IncompleteMatrix') end
      return false -- indicate element was already in the IncompleteMatrix
   end
end -- add

function IncompleteMatrix:averageValue()
   local v = makeVerbose(false, 'IncompleteMatrix:averageValue')
   local sum = 0
   local count = 0
   for rowIndex, colIndex, value in self:triples() do
      assert(rowIndex ~= nil)
      v('rowIndex,colIndex,value', rowIndex, colIndex, value)
      sum = sum + value
      count = count + 1
      v('updated sum,count', sum, count)
   end
   if count == 0 then
      error('IncompleteMatrix:averageValue no entries')
   end
   return sum / count
end -- averageValue

function IncompleteMatrix:clone()
-- return a share-nothing Incomplete Matrix with identical values as self
-- NOTE: this method is called frequently, so a fast approach is used
-- to implement it. It would be much slower to build up the clone by
-- iterating over all the known elements.

   local trace = false
   local me = 'IncompleteMatrix:clone '

   -- constuct new IncompleteMatrix
   local new = torch.factory('IncompleteMatrix')()
   new:__init()
   if trace then print(me .. 'new after init') print(new) end

   new.known = self.known
   new.nColumns = self.nColumns
   new.nRows = self.nRows
   new.nElements = self.nElements

   if trace then print(me .. 'new after setting') print(new) end

   return new
end -- clone

function IncompleteMatrix.deserialize(path)
-- return IncompleteMatrix object in file path
-- NOTE: class method
   local trace = false
   local me = 'IncompleteMatrix.deserialize'

   -- type and value check
   local temp = torch.factory('IncompleteMatrix')()
   temp:__init()
   temp:_checkString(path, 'path')

   local file = torch.DiskFile(path, 'r')
   assert(file, 'could not open file: ' .. path)
   
   local obj = file:readObject()

   -- verify that a 2D Tensor was read
   if trace then 
      print(me .. 'typename(obj)', torch.typename(obj)) 
   end

   assert(string.match(torch.typename(obj), 'IncompleteMatrix'),
          'file object not an IncompleteMatrix')

   file:close()
   
   return obj -- return an IncompletMatrix object
end -- deserialize

function IncompleteMatrix:equals(other, tolerance)
   -- return true iff every element is equal to other within the tolerance
   -- NOTE: the tolerance may be needed if a Tensor is serialized and
   -- then deserialized, as the conversion to and from the external
   -- representation is not 100% precise
   local tolerance = tolerance or 1e-14
   local v = makeVerbose(false, 'IncompleteMatrix:equals')
   local function contains(a, b)
      -- return true if each element in a is in b
      for rowIndex, colIndex, value in a:triples() do
         local bValue = b:maybeGet(rowIndex, colIndex)
         local diff = value - bValue
         if math.abs(diff) > tolerance then
            v('rowIndex', rowIndex)
            v('colIndex', colIndex)
            v('value', value)
            v('bValue', bValue)
            v('diff', diff)
            return false
         end
      end
      return true
   end -- contains

   return 
      other ~= nil and
      torch.typename(other) == 'IncompleteMatrix' and
      self.nElements == other.nElements and
      self.nColumns == other.nColumns and
      self.nRows == other.nRows and
      contains(self, other) and
      contains(other, self)
   --]]
end -- equals

function IncompleteMatrix:get(rowIndex, colIndex)
   local maybeValue = self:maybeGet(rowIndex, colIndex)
   if maybeValue ~= nil
   then 
      return maybeValue 
   else
      error('no entry at [' .. 
            tostring(rowIndex) .. 
            ',' .. 
            tostring(colIndex) ']')
   end
end -- get

function IncompleteMatrix:maybeGet(rowIndex, colIndex)
   assert(rowIndex, 'rowIndex not provided')
   assert(type(rowIndex) == 'number' and
          math.floor(rowIndex) == rowIndex and
          rowIndex > 0,
          'rowIndex must be a postive integer')
   
   assert(colIndex, 'colIndex not provided')
   assert(type(colIndex) == 'number' and
          math.floor(colIndex) == colIndex and
          colIndex > 0,
          'colIndex must be a postiive integer')
   
   local row = self.known[rowIndex]
   if row == nil then
      return nil
   else
      return row[colIndex]               -- possibly nil
   end
end -- maybeGet

function IncompleteMatrix:getNColumns()
   return self.nColumns
end -- getNCols

function IncompleteMatrix:getNElements()
   return self.nElements
end -- getNElements

function IncompleteMatrix:getNRows()
   return self.nRows
end -- getNRows



function IncompleteMatrix:print(limitEntries)
-- ARGS
-- limitEntries : number >= 0
--                if > 0, only print specified number of entries
   limitEntries = limitEntries or 0
   print('IncompleteMatrix')
   print(string.format(' nRows = %d nColumns %d nElements %d', 
                       self.nRows,
                       self.nColumns,
                       self.nElements))

   local printed = 0
   for i,j,value in self:triples() do
      print(string.format(' [%d][%d] = %f',
                          i, j, value))
      printed = printed + 1
      if limitEntries > 0 and printed >= limitEntries then break end
   end
end -- print


function IncompleteMatrix:printHead(limitEntries)
   limitEntries = limitEntries or 10
   self:print(limitEntries)
end -- printHead

function IncompleteMatrix.serialize(path, im)
-- write serialized self to file
-- NOTE: class method

   -- type and value check
   local temp = torch.factory('IncompleteMatrix')()
   temp:__init()
   temp:_checkString(path, 'path')
   temp:_checkIncompleteMatrix(im, 'im')
   

   local file = torch.DiskFile(path, 'w')
   assert(file, 'could not open file: ' .. path)
   
   file:writeObject(im)

   file:close()
end -- serialize

function IncompleteMatrix:triples()
   -- iterate over elements returning rowIndex, colIndex, value
   -- ref: Programming in Lua, p 80
   local v, tracing = makeVerbose(false, 'IncompleteMatrix:triples')

   local function generate()
      -- yield either rowIndex, colIndex, value
      --           or nil
      v('self', self)
      for rowIndex = 1, self.nRows do
         for colIndex = 1, self.nColumns do
            local maybeValue = self:maybeGet(rowIndex, colIndex)
            v('rowIndex,colIndex,maybeValue', rowIndex, colIndex, maybeValue)
            if maybeValue ~= nil then
               v('generate yields', rowIndex, colIndex, maybeValue)
               coroutine.yield(rowIndex, colIndex, maybeValue)
            end
         end
      end
      v('generate yields nil, nil, nil')
      coroutine.yield(nil, nil, nil)
   end -- generate

   local co = coroutine.create(generate)

   local function iterate()
      local error, a, b, c = coroutine.resume(co)
      if error == nil then
         print('Error in coroutine: ', a) -- a is the message
         error('error in IncompleteMatrix:triples()')
      else
         return a, b, c
      end
   end -- iterate

   return iterate
end -- triples


-----------------------------------------------------------------------------
-- private methods
-----------------------------------------------------------------------------


function IncompleteMatrix:_checkIncompleteMatrix(value, name)
   assert(value, name .. ' must be supplied')
   assert(string.match(torch.typename(value), 'IncompleteMatrix'),
          name .. ' not an IncompleteMatrix')
end

function IncompleteMatrix:_checkIndices(rowIndex, colIndex, testUpperBound)
   if testUpperBound == nil then testUpperBound = true end

   affirm.isIntegerPositive(rowIndex, 'rowIndex')
   if testUpperBound then
      assert(rowIndex <= self.nRows, 'rowIndex exceeds number of rows')
   end

   affirm.isIntegerPositive(colIndex, 'colIndex')
   if testUpperBound then
      assert(colIndex <= self.nColumns, 'colIndex exceeds number of columns')
   end
end

function IncompleteMatrix:_checkString(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'string',
          name .. ' must be a Lua string')
end

