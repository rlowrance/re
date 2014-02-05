-- NamedMatrix.lua
-- a great simplification of Dataframe with many of same benefits

require 'bytesIn'
require 'equalObjectValues'
require 'isnan'
require 'makeVp'
require 'memoryUsed'
require 'printTableVariable'
require 'sequenceContains'
require 'splitString'
require 'Timer'

-- API overview
if false then
   -- constructing
   factorLevels.a = {'abc', 'def', 'ghi'}
   factorLevels.b = {'one', 'two'}
   nm = NamedMatrix{tensor=tensor, names={'a', 'b', 'c'}, levels=factorLevels}
   --         tensor can be 1D, 2D, or sequence of numbers
   nm = NamedMatrix.readCsv{    
      file='path/to/file',
      sep=string,                     -- default ','
      nanString=string,               -- default '' (missing)
      nRows=integer,                  -- default -1 (read all rows)
      numberColumns=seqStrings,       -- names of number columns, default {}
      factorColumns=seqStrings,       -- names of factor columns, default {}
      skip=number,                    -- default 0
      headerString='a,b,c'            -- only if file has no header
                             }
                             
   newNm = nm:dropColumn('b')
   newNm = nm:head(n)                 -- only first n rows
   nm1, nm2 = nm:splitRows(toNm1F(rowIndex))  -- if F(), then put in nm1
   nm = NamedMatrix.merge{nmX=nm1, nmY=nm2, 
                          byX=colNameinX, byY=colNameInY,
                          newBy=nameForNewColumn}
   nm = NamedMatrix.concatenateHorizontally(nm1, nm2)  -- adding columns
   nm = nm:onlyColumns({'a', 'b', 'c'})

   -- public fields
   tensor2D = nm.t                -- 2D Tensor
   nameSequence = nm.names        -- sequence of names for columns of nm.t
   factorLevels = nm.levels['a']  -- factorLevels[i] is string for t[i]['a']

   -- accessing (also use nm.t[i][j])
   number = nm:get(i, 'a')         -- return number
   string = nm:getLevel(i, 'a')    -- return string
   string = nm:getLevel(i, j)      -- return string

   -- testing
   if nm1:equalValue(nm2) then 
      -- each element is the same, addresses may differ
   end

   -- operate on a column name
   kind = nm:columnKind(string)  -- in {'number', 'factor'} or nil if invalid
   int = nm:columnIndex(string)

   -- utility
   nm:print{n=3,maxlevels=10,name='varName'}  -- print 3 rows at most 10 levels
   nm:writeCsv{file = "path/to/file",
               colNames = boolean,        -- default true
               sep = string,              -- default ','
               nanString = string,        -- default ''
               quote = boolean            -- default false
              }
end

local NamedMatrix = torch.class('NamedMatrix')
-- construct new NamedMatrix
-- ARGS is a single table t with these fields
-- t.tensor : a 1D or 2D Tensor or sequence,
--            1D Tensor and sequence converted to n X 1 2D Tensor (col vector)
-- t.names  : seq of strings
--            name of column i is t.names[i]
-- levels   : a table with string for factor levels
--            levels.f[3] == string for value 3 in column named f
function NamedMatrix:__init(t)
   local vp = makeVp(0, 'NamedMatrix:__init')
   assert(t.tensor ~= nil,
         'tensor is nil')
   assert(type(t.names) == 'table' and type(t.names[1]) == 'string',
         'names is not a sequence of strings')
   assert(type(t.levels) == 'table',
         'levels is not a table')

   -- adjust tensor arg
   local tensor
   if type(t.tensor) == 'table' then
      tensor = torch.Tensor{t.tensor}
   elseif t.tensor:dim() == 1 then
      tensor = torch.Tensor(1, t.tensor:size(1))
      for i = 1, t.tensor:size(1) do
         tensor[1][i] = t.tensor[i]
      end
   elseif t.tensor:dim() == 2 then
      tensor = t.tensor
   else
      vp(0, 't.tensor:size()', t.tensor:size())
      error('bad t.tensor')
   end

   -- establish public fields
   self.t = tensor:clone()
   self.names = t.names
   self.levels = t.levels
end

-- new NamedMatrix that concatenates two NamedMatrices
-- ARGS
-- a : NamedMatrix of size m x n
-- b : NamedMatrix of size m x k, with distinct column names
-- RESULT
-- newNamedMatrix : NamedMatrix of size m x (n + k)
function NamedMatrix.concatenateHorizontally(a, b)
   assert(torch.typename(a) == 'NamedMatrix')
   assert(torch.typename(b) == 'NamedMatrix')
   local m = a.t:size(1)
   local n = a.t:size(2)
   assert(b.t:size(1) == m)
   local k = b.t:size(2)

   -- check that column names are different
   local aNames = {}
   for _, aName in ipairs(a.names) do
      aNames[aName] = true
   end

   for _, bName in ipairs(b.names) do
      assert(aNames[bName] == nil,
             string.format('column %s is in b and also in a',
                           bName))
   end

   -- build new NamedMatrix
   local newTensor = torch.Tensor(m, n + k)
   for rowIndex = 1, m do
      for colIndex = 1, n do
         newTensor[rowIndex][colIndex] = a.t[rowIndex][colIndex]
      end
      for colIndex = 1, k do
         newTensor[rowIndex][n + colIndex] = b.t[rowIndex][colIndex]
      end
   end

   local newNames = {}
   for _, aName in ipairs(a.names) do
      table.insert(newNames, aName)
   end
   for _, bName in ipairs(b.names) do
      table.insert(newNames, bName)
   end

   local newLevels = {}
   for k, v in pairs(a.levels) do
      newLevels[k] = v
   end
   for k, v in pairs(b.levels) do
      newLevels[k] = v
   end

   return NamedMatrix.new{tensor=newTensor, names=newNames, levels=newLevels}
end

-- new NamedMatrix with one column dropped
-- ARGS:
-- columnName : string, name of column which must be present
-- RESULT: 
-- newNamedMatrix    : NamedMatrix
function NamedMatrix:dropColumn(columnName)
   assert(type(columnName) == 'string')
   local newNames = {}
   local droppedColumnIndex = nil
   for i, name in ipairs(self.names) do
      if name == columnName then
         droppedColumnIndex = i
      else
         table.insert(newNames, name)
      end
   end
   assert(droppedColumnIndex)

   -- build new tensor that is missing one column
   local tensor = torch.Tensor(self.t:size(1), self.t:size(2) - 1)
   for r = 1, self.t:size(1) do
      local columnIndex = 0
      for c = 1, self.t:size(2) do
         if c ~= droppedColumnIndex then
            columnIndex = columnIndex + 1
            tensor[r][columnIndex] = self.t[r][c]
         end
      end
   end
   return NamedMatrix.new{tensor=tensor,
                          names=newNames,
                          levels=self.levels}
end

-- return column index for a specified column name
-- ARGS:
-- columnName  : string
-- RETURNS
-- columnIndex : integer
function NamedMatrix:columnIndex(columnName)
   assert(type(columnName) == 'string')
   local columnIndex = nil

   for i, name in ipairs(self.names) do
      if name == columnName then
         return i
      end
   end

   error('column ' .. columnName .. ' is not in NamedMatrix')
end

-- kind of column, 'factor' or 'number'
-- ARGS
-- columnName : string, name of column
-- RETURNS
-- kind       : string in {'factor', 'number'} or nil of column not present
function NamedMatrix:columnKind(columnName)
   assert(type(columnName) == 'string')
   if sequenceContains(self.names, columnName) then
      local levels = self.levels[columnName]
      if levels then
         return 'factor'
      else
         return 'number'
      end
   else
      return nil
   end
end

-- return value at row number and column name
-- ARGS
-- rowIndex   : integer > 0
-- columnName : string
-- RETURNS
-- number     : self.t[rowIndex][columnIndex]
function NamedMatrix:get(rowIndex, columnName)
   assert(type(rowIndex) == 'number')
   assert(type(columnName) == 'string')

   return self.t[rowIndex][self:columnIndex(columnName)]
end

-- return level (string) for given matrix entry
-- ARGS
-- rowIndex : integer > 0
-- colName  : integer > 0 or string, a column name
local lastColumnName = nil
local lastColumnIndex = nil
function NamedMatrix:getLevel(rowIndex, colName)
   assert(type(rowIndex) == 'number')

   local colIndex = nil
   if type(colName) == 'number' then
      colIndex = colName
      colName = self.names[colIndex]
   elseif type(colName) == 'string' then
      colIndex = self:columnIndex(colName)
   else
      error('colName not string nor integer')
   end

   local value = self.t[rowIndex][colIndex]
   return self.levels[colName][value]
end

-- new NamedMatrix with only first n rows
-- ARGS:
-- n : integer > 0, number of rows to keep
-- RETURNS
-- newNamedMatrix : NamedMatrix
function NamedMatrix:head(n)
   assert(type(n) == 'number')
   assert(n > 0 and math.floor(n) == n)
   
   local newTensor = torch.Tensor(n, self.t:size(2))
   for i = 1, n do
      newTensor[i] = self.t[i]
   end

   return NamedMatrix.new{tensor=newTensor,
                          names=self.names,
                          levels=self.levels}
end

-- create new NamedMatrix by merging two others
-- ARGS: a table t with these elements
-- t.nmX   : NamedMatrix
-- t.nmY   : NamedMatrix
-- t.byX   : string, column in X used for the merge
-- t.byY   : string, column in Y used for the merge
-- t.newBy : string, column that replaces byX and byY in new NamedMatrix
-- RETURNS
-- newNm : contains every row in which t.byX == t.byY
function NamedMatrix.merge(t)
   -- set the verboseLevel to 2 to trace execution when finding out of memory
   -- problems
   local debug = true  -- track down timing problem
   local vp = makeVp(0, 'NamedMatrix.merge')
   --vp(1, 't', t)  PRINTS A LOT
   assert(t ~= nil)
   local arg = t

   -- validate args
   assert(torch.typename(arg.nmX) == 'NamedMatrix')
   assert(torch.typename(arg.nmY) == 'NamedMatrix')
   assert(type(arg.byX) == 'string')
   assert(type(arg.byY) == 'string')
   assert(type(arg.newBy) == 'string')

   -- for now, neither key field can be a factor
   assert(arg.nmX:columnKind(arg.byX) == 'number')
   assert(arg.nmY:columnKind(arg.byY) == 'number')

   -- determine all values in byX column
   local rowByInX = {}
   local byXIndex = arg.nmX:columnIndex(arg.byX)
   for rowIndex = 1, arg.nmX.t:size(1) do
      local value = arg.nmX.t[rowIndex][byXIndex]
      if not rowByInX[value] then
         rowByInX[value] = rowIndex
      end
   end
   vp(2, 'determined all values in byX column')
   local used = memoryUsed()  -- collect garbage
   vp(2, 'bytes used', used)

   -- determine all values in byY that are also in byX
   local rowByInY = {}
   local inBoth = {}
   local countInBoth = 0
   local byYIndex = arg.nmY:columnIndex(arg.byY)
   for rowIndex = 1, arg.nmY.t:size(1) do
      --print(arg.nmY.t) print(rowIndex) print(byIndex)
      local value = arg.nmY.t[rowIndex][byYIndex]
      if rowByInX[value] then
         countInBoth = countInBoth + 1
         inBoth[value] = true
         rowByInY[value] = rowIndex
      end
   end
   vp(2, 'determined all values in byY that are also in byX')
   vp(2, 'bytes used', memoryUsed())

   -- copy rows with the common values inBoth to new tensor
   local rowsInX = arg.nmX.t:size(1)
   local colsInX = arg.nmX.t:size(2)
   local rowsInY = arg.nmX.t:size(1)
   local colsInY = arg.nmY.t:size(2)
   local newTensor = torch.Tensor(countInBoth, colsInX + colsInY - 2 + 1)
   vp(2, 'countInBoth', countInBoth)
   vp(2, 'allocated results Tensors')
   vp(2, 'bytes used', memoryUsed())
   -- out of memory after this statement

   -- copy all values in row except for the by column
   -- return end of last column in newTensor that was filled
   local copyRowTimer = Timer()
   local function copyRow(nm, by, rowByIndex, 
                          toRowIndex, commonValue, nextColumnToFill)
      local timer = Timer()
      local byColIndex = nm:columnIndex(by)
      for c, columnName in ipairs(nm.names) do
         if columnName ~= by then
            nextColumnToFill = nextColumnToFill + 1
            fromRowIndex = rowByIndex[commonValue]
            newTensor[toRowIndex][nextColumnToFill] = nm.t[fromRowIndex][c]
         end
      end
      if false and toRowIndex % 10000 == 1 then
         vp(1, string.format('toRowIndex % d / %d ' ..
                             'avg CPU %f secs ' ..
                             'avg Wall Clock %f secs',
                             toRowIndex, newTensor:size(1),
                             copyRowTimer:cpu() / toRowIndex, 
                             copyRowTimer:wallclock() / toRowIndex))
      end
         
      if debug and false then
         if toRowIndex % 100000 == 0 then
            -- don't garbage collect, to see if memory is really a problem
            vp(0, 'debug toRowIndex', toRowIndex)
         end
      end
      if false then
         -- periodically collect garbarge
         if toRowIndex % 1000 == 0 then
            local used = memoryUsed()  -- collect and report memory in use
            vp(2, 'copied to destination row index', toRowIndex)
            vp(2, 'bytes used in copyRow', used)
         end
      end
      return nextColumnToFill
   end
      
   -- elements of new Tensor
   local nextRowIndex = 0
   local timer = Timer()  -- start timer
   for commonValue in pairs(inBoth) do
      nextRowIndex = nextRowIndex + 1
      local restart = copyRow(arg.nmX, arg.byX, rowByInX,
                              nextRowIndex, commonValue, 0)
      local restart = copyRow(arg.nmY, arg.byY, rowByInY,
                              nextRowIndex, commonValue, restart)
      newTensor[nextRowIndex][restart + 1] = commonValue
      -- I measured the slowdown caused by collecting garbarge on every 
      -- update and found that doing so increased the run time by a factor 
      -- of 20.
      --collectgarbage()  -- MAYBE: not do this every time
      if nextRowIndex % 100000 == 1 then
         vp(1, string.format('fill newTensor: nextRowIndex %d / %d ' ..
                             'avg CPU %f ' ..
                             'avg Wall clock %f',
                             nextRowIndex, newTensor:size(1),
                             timer:cpu() / nextRowIndex,
                             timer:wallclock() / nextRowIndex))
      end
   end
   -- out of memory before this statement
   vp(2, 'copied all elements into new Tensor')

   local newNames = {}
   local function copyMostNames(nm, by) 
      for _, name in ipairs(nm.names) do
         if name ~= by then
            table.insert(newNames, name)
         end
      end
   end

   copyMostNames(arg.nmX, arg.byX)
   copyMostNames(arg.nmY, arg.byY)
   table.insert(newNames, arg.newBy)
   vp(2, 'copied most names')

   -- build up the new levels, assure no duplicate levels
   local newLevels = {}
   for k,v in pairs(arg.nmX.levels) do
      if newLevels[k] then
         error('column ' .. k .. ' is in nmX twice')
      end
      newLevels[k] = v
   end
   vp(2, 'built newLevels pass 1')

   for k,v in pairs(arg.nmY.levels) do
      if newLevels[k] then
         error('column ' .. k .. ' in nmY is also in nmX or is in nmY twice')
      end
      newLevels[k] = v
   end
   vp(2, 'built newLevels pass2')

   local result = 
      NamedMatrix.new{tensor=newTensor, names=newNames, levels=newLevels}
   vp(2, 'constructed result')
   return result
end

-- return new NamedMatrix containing selected columns
-- ARGS:
-- seq : sequence of column names
-- RETURNS
-- nmNew : NamedMatrix
function NamedMatrix:onlyColumns(seq)
   local vp = makeVp(0, 'NamedMatrix:onlyColumns')
   vp(1, 'seq', seq)
   assert(type(seq) == 'table')
   
   local nextColIndex = 0
   local newColIndex = {}
   local newLevels = {}
   for i, colName in ipairs(seq) do
      vp(2, 'colName from seq', colName)
      local kind = self:columnKind(colName)
      if kind == nil then
         error(colName .. ' is not in self')
      elseif kind == 'factor' then
         newLevels[colName] = self.levels[colName]
      end
      newColIndex[colName] = i
   end
   vp(2,
      'newColIndex', newColIndex,
      'newLevels', newLevels,
      'self.names', self.names)

   local newTensor = torch.Tensor(self.t:size(1), #seq)
   for _, colName in ipairs(seq) do
      local newIndex = newColIndex[colName]
      local oldIndex = self:columnIndex(colName)
      vp(2, 'colName', colName, 'newIndex', newIndex, 'oldIndex', oldIndex)
      for r = 1, self.t:size(1) do
         newTensor[r][newIndex] = self.t[r][oldIndex]
      end
   end

   return NamedMatrix.new{tensor=newTensor,
                          names=seq,
                          levels=newLevels}
end


-- print compactly on stdout
-- ARGS: a table t with these elements
-- t.n    : optional integer, default 6
--   number of values to print; optional if negative, print them all
-- t.name : optional string default '', variable name holding the Dataframe
-- maxlevels: integer, default 6
--   number of levels to print for factor columns; if negative, print them all
--
-- RETURNS the Dataframe
function NamedMatrix:print(t)
   local arg = {}
   t = t or {}
   arg.n = t.n or 6
   arg.maxlevels = t.maxlevels or 6
   arg.verbose = t.verbose or 0
   arg.name = t.name

   local vp = makeVp(arg.verbose, 'NamedMatrix:print')
   vp(1, 't', t)

   local m = self.t:size(1)
   local n = self.t:size(2)
   
   -- print header
   if arg.name then
      print(string.format('NamedMatrix %s with %d rows, %d columns',
                          arg.name, m, n))
   else
      print(string.format('NamedMatrix with %d rows, %d columns',
                          m, n))
   end
   
   print('values in the named columns')

   -- count number of NaN values in column
   local function countNaNs(colIndex)
      local count = 0
      for rowIndex = 1, m do
         if isnan(self.t[rowIndex][colIndex]) then
            count = count + 1
         end
      end
      return count
   end

   -- print levels of a factor
   local function printFactor(colName, colIndex)
      local s = ' levels:'
      local levels = self.levels[colName]
      for i, level in ipairs(levels) do
         if arg.maxlevels >= 0 and i > arg.maxlevels then
            s = s .. ' ...'
            break
         end
         s = s .. ' ' .. tostring(level)
      end
      print(s)
   end

   -- print values in one column, with line breaks every 6 elements
   local function printValues(colName, colIndex)
      local maxElementsToPrint = 6

      -- print first arg.n elements in the column
      local line = colName .. ':'
      for rowIndex = 1, math.min(arg.n, self.t:size(1)) do
         local value = self.t[rowIndex][colIndex]
         line = line .. ' ' .. tostring(value)
      end

      -- append '...' if more than maxEleemntsToPrint
      if self.t:size(1) > maxElementsToPrint then
         line = line .. ' ...'
      end

      print(line)
   end

   -- print a column
   local function printColumn(colName)
      local colIndex = self:columnIndex(colName)

      printValues(colName, colIndex)

      local nNans = countNaNs(colIndex)
      if nNans > 0 then
         print(string.format(' with %d NaNs', nNans))
      end

      if self:columnKind(colName) == 'factor' then
         printFactor(colName, colIndex)
      end
   end

   -- print each column
   for _, colName in ipairs(self.names) do
      printColumn(colName)
   end

   return self
end

-- read a CSV file
-- ARGS a single table t with these fields
-- t.file          : string, path to file
-- t.sep           : optional string, default ','
--                   string that separates fields in each line
-- t.nanString     : optional strig, default ''
--                   if the value of a field is this string, the value is NaN
-- t.nRows         : optional integer, default -1
--                   if > 0, read only this number of rows
-- t.numberColumns : sequence of strings, optional
--                   columns to be read as numbers (must be number or NaN)
-- t.factorColumns : sequence of strings, optional
--                   columns to be read as factors with corresponding levels
-- t.skip          : optional integer, default 0
--                   number of initial input records to skip
-- t.transformF    : optional function, transform input record
--                   ARGS:
--                   stringSeq : sequence of strings, parsed input record fields
--                   isHeader  : boolean, true iff stringSeq is the header
--                   RETURNS
--                   newStringSeq : sequence of strings, output record fields
-- t.headerString  : optional string
--                   If present, substitutes for a missing header in the file
--                   Use this if the file has no header, but you know the
--                   names of the columns
function NamedMatrix.readCsv(t)
   local vp, verbose = makeVp(0, 'NamedMatrix.readCsv')
   local d = verbose > 0
   assert(t ~= nil)
   local arg = t
   if d then vp(1,' arguments') printTableValue('t', t) end

   -- supply default values
   local function defaultTransformF(stringSeq, isHeader) 
      local vp = makeVp(0, 'NamedMatrix.readCsv::defaultTransformF')
      vp(2, 'stringSeq', stringSeq, 'isHeader', isHeader)
      return stringSeq 
   end

   if t.sep == nil then arg.sep = ',' end
   if t.nanString == nil then arg.nanString = '' end
   if t.nRows == nil then arg.nRows = -1 end
   if t.skip == nil then arg.skip = 0 end
   if arg.factorColumns == nil then arg.factorColumns = {} end
   if arg.numberColumns == nil then arg.numberColumns = {} end
   if arg.transformF == nil then arg.transformF = defaultTransformF end
   vp(1, 'arg after defaults applied', arg)

   -- validate args
   assert(type(arg.file) == 'string')
   assert(type(arg.sep) == 'string')
   assert(type(arg.nanString) == 'string')
   assert(type(arg.nRows) == 'number')
   assert(type(arg.numberColumns) == 'table')
   assert(type(arg.factorColumns) == 'table')
   assert(type(arg.skip) == 'number')
   assert(type(arg.transformF) == 'function')
   vp(1,'arg.headerStrring', arg.headerString)
   vp(1,'type', type(arg.headerString))
   assert((type(arg.headerString) == 'nil') or 
          (type(arg.headerString) == 'string'))

   -- open input file, skip initial records, and return unparsed header
   local function openSkipHeader()
      local vp = makeVp(0, 'openSkipHeader')
      local f, err = io.open(arg.file, 'r')
      if f == nil then 
         error('unable to open file ' .. arg.file .. ' message = ' .. err)
      end
      
      -- maybe skip initial records
      while arg.skip > 0 do
         local record = f:read()
         if record == nil then 
            error('end of file while skipping initial records')
         end
         arg.skip = arg.skip - 1
      end

      -- read header unless caller has specified it
      local header = nil
      if t.headerString then
         header = t.headerString
         vp(2, 'used supplied header string')
      else  
         header = f:read()
         vp(2, 'read header record')
      end

      vp(1, 'f', f, 'header', header)
      return f, header
   end
   
   -- read and parse header into sequence of string
   local f, header = openSkipHeader()
   if header == nil then error('did not find header') end
   local headerNames = {}
   local headerIndices = {}
   for i, headerName in ipairs(arg.transformF(splitString(header, arg.sep),
                                              true)) do
      table.insert(headerNames, headerName)
      headerIndices[headerName] = i
   end
   vp(2, 'headerNames', headerNames)  -- all the header names
   vp(2, 'headerIndices', headerIndices)
   if d then
      for i, headerName in ipairs(headerNames) do
         print('headerNames[' .. tostring(i) .. ']=' .. tostring(headerName))
      end
   end

   local fieldColumnIndex = {}
   for i, name in ipairs(headerNames) do
      fieldColumnIndex[name] = i
   end

   -- accumulate all column names
   local retainedColumnNames = {}
   local isNumberColumn = {}
   local isRetainedColumn = {}
   for _, columnName in ipairs(arg.numberColumns) do
      table.insert(retainedColumnNames, columnName)
      isNumberColumn[columnName] = true
      isRetainedColumn[columnName] = true
   end
   for _, columnName in ipairs(arg.factorColumns) do
      table.insert(retainedColumnNames, columnName)
      isRetainedColumn[columnName] = true
   end
   vp(2, 'isNumberColumn', isNumberColumn)
   vp(2, 'retainedColumnNames', retainedColumnNames)
   vp(2, 'isRetainedColumn', isRetainedColumn)
   if d then 
      for k, v in pairs(retainedColumnNames) do
         print('retainedColumnNames[' .. tostring(k) .. ']=' .. tostring(v))
      end
   end

   -- read records into a numeric sequence for each column
   
   -- NOTE: don't build large values table, as if more then 1GB, LuaJIT fails
   if arg.nRows == -1 then
      -- set arg.nRows to number of input records
      vp(1, 'counting input records by reading the file')
      arg.nRows = 0
      while true do
         local record = f:read()
         if record == nil then break end
         arg.nRows = arg.nRows + 1
      end
      f:close()
      f = openSkipHeader()
   end
   vp(2, 'arg.nRows', arg.nRows)

   -- setup 3 tables:
   -- levelsOfString[colName] = table where
   --   table[stringValue] == numberValue (the index)
   -- nextOffset[colNumber] == next numberValue for the column
   -- level[colName] == seq where
   --   seq[numberValue] = stringValue
   local levelOfString = {}
   local nextOffset = {}
   local levels = {}
   for _, colName in ipairs(retainedColumnNames) do
      if not isNumberColumn[colName] then
         levelOfString[colName] = {}     -- will be table[string] = n
         nextOffset[colName] = 0
         levels[colName] = {}            -- will be a sequence[n] = string
      end
   end
   if d then
      vp(2, 'retainedColumnNames', retainedColumnNames)
      vp(2, 'levels', levels)
      for k,v in pairs(levelOfString) do
         vp(2, 'levelOfString[' .. k .. ']', v)
      end
   end

   -- read each data row, store values in the 2D Tensor
   vp(1, 'reading the file to convert and store data')
   local tensor = torch.Tensor(arg.nRows, #retainedColumnNames)
   local nRead = 0
   local foundEOF = false
   for rowIndex = 1, arg.nRows do
      local record = f:read()
      if record == nil then
         foundEOF = true
         break
      end
      nRead = nRead + 1
      if nRead % 100000 == 0 then
         vp(1, 'read data record number', nRead)
      end
      vp(2, 'nRead', nRead)
      -- split data record into fields and transform
      -- false ==> not a header (this is a data record)
      local fields = arg.transformF(splitString(record, arg.sep), false)
      -- process each transformed field
      for tensorColIndex, colName in ipairs(retainedColumnNames) do 
         vp(3, 'tensorColIndex', tensorColIndex, 'colName', colName)
         local headerIndex = headerIndices[colName]
         assert(headerIndex ~= nil,
               string.format('there is no column with name %s',
                             colName))
         local valueString = fields[headerIndex]  -- a string
         vp(3, 'headerIndex', headerIndex, 'valueString', valueString)

         -- convert valueString to a number
         local valueNumber = nil
         if valueString == arg.nanString then
            valueNumber = 0 / 0
         elseif isNumberColumn[colName] then
            valueNumber = tonumber(valueString)
            if valueNumber == nil then
               print('record=' .. record)
               printTableValue('fields', fields)
               print('valueString = ' .. tostring(valueString))
               error('data record ' .. nRead .. 
                     ' column ' .. colName ..
                     ' has non-numeric value ' .. tostring(valueNumber))
            end
         else -- is factor column
            -- convert string value to number and build levels
            --vp(2, 'factor column name', colName)
            --vp(2, 'levelOfString[colName]', levelOfString[colName])
            valueNumber = levelOfString[colName][valueString]
            vp(3, 'valueString', valueString, 'valueNumber', valueNumber)
            vp(3, 'colName', colName)
            if valueNumber == nil then
               nextOffset[colName] = nextOffset[colName] + 1
               levelOfString[colName][valueString] = nextOffset[colName]
               table.insert(levels[colName], valueString)
               valueNumber = levelOfString[colName][valueString]
            end
         end
         vp(3, 'valueNumber', valueNumber)
         tensor[rowIndex][tensorColIndex] = valueNumber
      end
      vp(3, 'next tensor row', tensor[rowIndex])
   end

   if foundEOF then
      assert(arg.nRows == nRead)
   else
      local record = f:read()
      if record ~= nil then
         vp(0, 'WARNING: DID NOT READ ALL RECORDS FROM FILE ' .. arg.file)
      end
   end

   -- explicitly free intermediate tables in attempt to avoid bug in luaJIT
   -- see below for bug
   
   levelOfString = nil
   nextOffset = nil

   local result = NamedMatrix.new{tensor=tensor, 
                                  names=retainedColumnNames, 
                                  levels=levels}

   -- NOTE: if using LuaJIT, if any lua object exceeds 1GB, garbage collection
   -- will eventually fail.
   if jit and false then
      -- using LuaJIT
      local gib = 1024 * 1024 * 1024  -- 1 GiB
      local size = bytesIn(result)
      assert(size < gib,
             'NamedMatrix.readCsv result too large; ' .. tostring(size))
   end

   return result
end

-- 2 new NamedMatrices with rows split according to an true-false sequence
-- ARGS
-- toNm1F(rowIndex) : function of one variable returning boolean
--       the row goes to nm1 if returns true, otherwise to nm2
-- RESULT:
-- nm1 : NamedMatrix
-- nm2 : NamedMatrix
function NamedMatrix:splitRows(toNm1F)
   local vp = makeVp(0, 'NamedMatrix:splitRows')
   assert(type(toNm1F) == 'function')
   vp(1, 'self.t size', self.t:size())

   -- determine size of each split
   local n1 = 0
   local n2 = 0
   local to1 = {}
   for rowIndex = 1, self.t:size(1) do
      local value = toNm1F(rowIndex)
      table.insert(to1, value)
      if value then
         n1 = n1 + 1
      else
         n2 = n2 + 1
      end
      --if rowIndex % 1 == 0 then vp(2, 'rowIndex', rowIndex) end
   end
   vp(2, '#to1', #to1)

   if n1 == 0 then
      vp(1, 'first split is empty')
      return nil, NamedMatrix.new{tensor=self.t, 
                                  names=self.names, 
                                  levels=self.levels}
   end

   if n2 == 0 then
      vp(1, 'second split is empty')
      return NamedMatrix.new{tensor=self.t, 
                             names=self.names, 
                             levels=self.levels},
             nil
   end

   local t1 = torch.Tensor(n1, self.t:size(2))
   local t2 = torch.Tensor(n2, self.t:size(2))
   vp(2,
      'n1', n1,
      'n2', n2,
      'self.t:size(2)', self.t:size(2))
   vp(2, 't1:size()', t1:size())
   vp(2, 't2:size()', t2:size())

   local i1 = 0
   local i2 = 0
   for i, value in ipairs(to1) do
      if value then
         i1 = i1 + 1
         t1[i1] = self.t[i]
      else
         i2 = i2 + 1
         t2[i2] = self.t[i]
      end
   end
   
   return
      NamedMatrix.new{tensor=t1, names=self.names, levels=self.levels},
      NamedMatrix.new{tensor=t2, names=self.names, levels=self.levels}
end

-- write csv file, replacing factor values with their string levels
-- ARGS: a single table t with these elements
-- t.file      : string, path to file
-- t.colNames  : optional boolean, default true
--               if true, write the column names as the file header
-- t.sep       : optional string, default ','
--               this string separates each column
-- t.nanString : optional string, default ''
--               if the value is NaN, write this string instead of nan
-- t.quote     : optional boolean, default false
--               if true, surround strings with this character
function NamedMatrix:writeCsv(t)
   local vp = makeVp(0, 'NamedMatrix:writeCsv')
   vp(1, 't', t)
   assert(t ~= nil)
   local arg = {}

   -- build arg, supply defaults
   arg = t
   if t.colNames == nil then arg.colNames = true end
   if t.sep == nil then arg.sep = ',' end
   if t.nanString == nil then arg.nanString = '' end
   if t.quote == nil then arg.quote = false end
   vp(2, 'arg', arg)

   -- validate args
   assert(type(arg.file) == 'string')
   assert(type(arg.colNames) == 'boolean')
   assert(type(arg.sep) == 'string')
   assert(type(arg.nanString) == 'string')
   assert(type(arg.quote) == 'boolean')

   -- open file
   local f, err = io.open(arg.file, 'w+')
   if f == nil then error('unable to open file ' .. arg.file) end

   -- maybe write header
   if arg.colNames then
      local firstField = true
      for _, name in pairs(self.names) do
         if not firstField then
            f:write(arg.sep)
         end
         firstField = false
         f:write(name)
      end
      f:write("\n")
   end

   local function writeString(s)
      if arg.quote then
         f:write(arg.quote .. s .. arg.quote)
      else
         f:write(s)
      end
   end

   -- write each record
   for rowIndex = 1, self.t:size(1) do
      local firstField = true
      for colIndex = 1, self.t:size(2) do
         if not firstField then f:write(arg.sep) end
         firstField = false
         local value = self.t[rowIndex][colIndex]
         if isnan(value) then
            -- value is NaN
            writeString(arg.nanString)
         elseif self:columnKind(self.names[colIndex]) == 'factor' then
            -- value is a known factor 
            writeString(self.levels[self.names[colIndex]][value])
         else
            -- value is a number
            f:write(value)
         end
      end
      f:write('\n')
   end

   f:close()

   return self
end

-- do two NamedMatrices have the same values (not addresses)?
-- ARGS:
-- other     : arbitrary object, usually a NamedMatrix
-- RETURNS
-- sameValue : boolean
function NamedMatrix:equalValue(other)
   return 
      torch.typename(other) == 'NamedMatrix' and
      equalObjectValues(self.t, other.t) and
      equalObjectValues(self.names, other.names) and
      equalObjectValues(self.levels, other.levels)
end
