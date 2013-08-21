-- Dataframe.lua
-- mimics an R data.frame

require 'asFactor'
require 'head'
require 'ifelse'
require 'keys'
require 'makeVp'
require 'sequenceContains'
require 'splitString'

-- API overview
if false then
  -- constructing
   df = Dataframe {values = tableExp, levels = tableExp} -- if some factors
   df = Dataframe {values = tableExp}                    -- if no factors

   -- this method seems buggy on large files. Use newFromFile2 if possible
   df = Dataframe.newFromFile{    -- mimic R's read.table
      file = "path/to/file",      
      header = boolean,           -- default true
      nRows = integer,            -- number of data rows
      sep = string,               -- default ","
      stringsAsFactors = boolean, -- default true
      naStrings = seqOfStrings,   -- default {"NA", ""}
      skip = number               -- default 0
                             }

  -- special case: always a header, type of fields named specificially    
  -- only one NA string in file. Fails if a number column has a non number.
  df = Dataframe.newFromFile2{        -- special case, much faster than general
      file='path/to/file',
      sep=string,                     -- default ','
      naString=string,                -- default '' (missing)
      nRows=integer,                  -- default -1 (read all rows)
      numberColumns=seqStrings,       -- names of number columns, default {}
      stringColumns=seqStrings,       -- names of string columns, default {}
      factorColumns=seqStrings,       -- names of factor columns, default {}
      skip=number                     -- default 0
                             }

   df = Dataframe.newFromMerge{   -- merge on one fields
      dfX = dfx,
      dfY = dfy,
      byX = colNameInDfx,         -- column in dfx to match
      byY = colNameInDfy          -- column in dfy to match
                              }

   df = Dataframe.newEmpty()      -- has no rows nor columns

   df1, df2 = df:splitString(fractionToDf1)  -- split rows randomly into 2 pieces


   -- a place holder for missing values
   NA = Dataframe.NA

  -- accessing components
   names = df:columnNames()               -- seq of all column names
   numericNames = df:numberColumnNames()  -- just the number columns
   factorNames = df:factorColumnNames()   -- just the factor columns
   stringNames = df:stringColumnNames()   -- just the string columns
   values = df:column('abc')              -- values in one column

   -- constructing new Dataframe by selecting subsets
   df2 = df:dropColumns{"a", "b"}         -- drop specified columns
   df2 = df:onlyColumns{"a", "b"}         -- keep only specified columns
   df2 = df:head(6)                       -- keep only first 6 rows
   df2 = df:onlyRows(seq)                 -- keep only rows with seq[i] == true
   df2 = df:row(n)                        -- keep only row n

   -- mutating
   df:addColumn(colName, values)          -- add or replace column
   df:dropColumn(colName)                 -- delete existing column
   
   -- printing on stdout
   df:print{n=3,maxlevels=10}             -- print at most 3 values per column

   -- inquiries
   df:get("col name", index)    -- values at row index of column "col name"
   df:level("col name", index)  -- level name for factor[col name, i]
   df:kind("col name")          -- oneOf {"number", "string", "factor", "allNA"}
   df:nRows()
   df:nCols()

   -- reading (mimic R's read.table); constructor

   df:writeCsv{file = "path/to/file",
               colNames = boolean,        -- default true
               sep = string,              -- default ","
               naString = string,         -- default ""
               quote = boolean            -- default false
              }

   -- convert to 2D tensor replacing Dataframe.NA values with NaN
   colNames = {"a", "b"}
   tensor, levels = df:asTensor(colNames)    -- extract columns "a" and "b"
   tensor1D = df:asTensor{'a'}
end  -- examples


-- create class object
local Dataframe = torch.class('Dataframe')

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

Dataframe.NA = {}

--------------------------------------------------------------------------------
-- METHODS
--------------------------------------------------------------------------------

-- construct a new Dataframe
--
-- ARGS
-- 
-- argTable.values (required) is a table 
--   key = name of column
--   value = a sequence with the same type
--           all the sequences in argTable.values should be the same length
--
-- argTable.levels (optional) is a table
--   key = name of a column that is a factor
--   value = a sequence of strings of names of the factor's levels
--
-- Returns: a new Dataframe object 
function Dataframe:__init(argTable)
   local arg = {}
   arg.values = argTable.values or error('must supply values argument')
   arg.levels = argTable.levels or {}

   assert(type(arg.values) == 'table', 'values must be a sequence')
   assert(type(arg.levels) == 'table', 'levels must be a sequence')

   -- each value must be a sequence (check only that each is a table)
   for k, v in pairs(arg.values) do
      assert(type(v) == "table", 'value ' .. k .. ' is not a table')
   end
   self.values = arg.values

   -- each level must be a sequence (check only that each is a table)
   for k, v in pairs(arg.levels) do
      assert(type(v) == 'table', 'level ' .. k .. ' is not a table')
   end
   self.levels = arg.levels
end

-- return seq of names of all columns
function Dataframe:columnNames()
   local res = {}
   for colName, _ in pairs(self.values) do
      res[#res + 1] = colName
   end
   return res
end

-- return names of specified kind
function Dataframe:_specified(wanted) 
   local res = {}
   for colName, _ in pairs(self.values) do
      if self:kind(colName) == wanted then
         res[#res + 1] = colName
      end
   end
   return res
end

-- return seq of names for numeric columns
function Dataframe:numberColumnNames()
   return self:_specified('number')
end

-- return seq of names for factor columns
function Dataframe:factorColumnNames()
   return self:_specified('factor')
end

-- return seq of names for string columns
function Dataframe:stringColumnNames()
   return self:_specified('string')
end

-- print compactly on stdout
-- 
-- ARGS: a table with these elements
--
-- n: optional integer, default 6
-- number of values to print; optional if negative, print them all
-- name: optional string default '', variable name holding the Dataframe
-- maxlevels: integer, default 6
--   number of levels to print for factor columns; if negative, print them all
--
-- RETURNS the Dataframe
function Dataframe:print(t)
   local arg = {}
   t = t or {}
   arg.n = t.n or 6
   arg.maxlevels = t.maxlevels or 6
   arg.verbose = t.verbose or 0
   arg.name = t.name

   local vp = makeVp(arg.verbose, 'Dataframe:print')
   vp(1, 't', t)
   
   if arg.name then
      print(string.format('Dataframe %s with %d rows, %d columns',
                          arg.name, self:nRows(), self:nCols()))
   else
      print(string.format('Dataframe with %d rows, %d columns',
                          self:nRows(), self:nCols()))
   end

   for colName, values in pairs(self.values) do
      -- print values
      vp(3, 'colName', colName)
      vp(3, 'head(values)', head(values))
      local function kind6()
         local kind = self:kind(colName)
         if #kind == 5 then 
            return kind .. ' '
         else
            return kind
         end
      end
      -- capture the first few values and convert them into string s
      local s = kind6() .. ' ' .. colName .. ':'
      for i, value in ipairs(values) do
         vp(3, 'i', i); vp(3, 'value', value)
         if arg.n >= 0 and i > arg.n then
            s = s .. ' ...'
            break
         end
         local sValue
         if value == Dataframe.NA then
            sValue = 'NA'
         else
            sValue = tostring(value)
         end
         vp(3, 'sValue', sValue)
         s = s .. ' ' .. sValue
      end
      print(s)

      local function countNAs(seq)
         local count = 0
         for _, element in ipairs(seq) do
            if element == Dataframe.NA then
               count = count + 1
            end
         end
         return count
      end

      local nNAs = countNAs(values)
      if nNAs > 0 then
         print(string.format(' with %d NAs', nNAs))
      end

      -- print levels, if column is a factor
      local kind = self:kind(colName)
      vp(3, 'kind', kind)
      
      if kind ~= 'factor' then
         --print(' ' .. kind)
      else
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
      --stop()
   end

   return self
end

function Dataframe:get(name, index)
   local values = self.values[name]
   assert(values, name .. ' is not a column name')
   return values[index]
end

function Dataframe:level(name, index)
   assert(self.levels[name], name .. ' is not a factor')
   local value = self:get(name, index)
   return self.levels[name][value]
end

function Dataframe:nRows()
   for _, value in pairs(self.values) do
      return # value
   end
   return 0
end

function Dataframe:nCols()
   local n = 0
   for _, _ in pairs(self.values) do
      n = n + 1
   end
   return n
end

function Dataframe:kind(name)
   local t = self.values[name]
   assert(t, 'not the name of a column: ' .. name)
   for _, oneValue in ipairs(t) do
      if oneValue == Dataframe.NA then
      elseif type(oneValue) == "number" then
         if self.levels[name] then 
            return "factor"
         else
            return "number"
         end
      elseif type(oneValue) == "string" then
         return "string"
      end
   end
   return "allNA"
end


function Dataframe:writeCsv(argTable)
   local arg = {}
   arg.file = argTable.file or error('missing file argument')
   arg.colNames = argTable.colNames or true
   arg.sep = argTable.sep or ","
   arg.naString = argTable.naString or ""
   arg.quote = argTable.quote or false

   -- open file
   local f, err = io.open(arg.file, "w")
   if f == nil then error("unable to open file " .. arg.file) end
   
   -- write header
   if arg.colNames then
      local firstField = true
      for k, _ in pairs(self.values) do
         if not firstField then
            f:write(arg.sep)
         end
         firstField = false
         f:write(k)
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
   for i = 1, self:nRows() do
      local firstField = true
      for colName, values in pairs(self.values) do
         if not firstField then 
            f:write(arg.sep) 
         end
         firstField = false
         local kind = self:kind(colName)
         local value = values[i]
         if value == Dataframe.NA then
            f:write(arg.naString)
         else
            if kind == "factor" then
               writeString(self:level(colName, value))
            elseif kind == "string" then
               writeString(value)
            else
               f:write(value)
            end
         end
      end
      f:write("\n")
   end

   f:close()
end

-- convert to a 2D Tensor and level names
--
-- ARGS
--
-- colnames: seq of strings, the names of the columns to convert
--
-- RETURNS two values
--
-- tensor: a 1D or 2D Tensor, with NA values converted to NaN
--
-- levels: a table
--   key = a string, the name of a  column
--   value = a seq, the level names for the column 
function Dataframe:asTensor(colNames)
   local vp = makeVp(0, 'Dataframe:asTensor')

   -- build the tensor returned value
   vp(1, 'colNames', colNames)
   vp(1, 'self is ' .. self:nRows() .. ' x ' .. self:nCols())
   local t = torch.Tensor(self:nRows(), #colNames)
   vp(2, 't', t)
   local colIndex = 0
   for _, colName in ipairs(colNames) do
      vp(2, 'colName ', colName)
      local values = self.values[colName]
      -- make sure column exists
      if not values then
         error(string.format('column %s is not in the Dataframe', colName))
      end
      -- assure that the column is numeric
      local kind = self:kind(colName)
      if kind ~= 'number' and kind ~= 'factor' then
         error(string.format('column %s is not numeric', colName))
      end
      colIndex = colIndex + 1
      for rowIndex, value in ipairs(values) do
         if value == Dataframe.NA then
            t[rowIndex][colIndex] = 0 / 0  -- convert NA to NaN
         else
            t[rowIndex][colIndex] = value
         end
      end
   end

   -- build the levels returned value
   local levels = {}
   for _, colName in ipairs(colNames) do
      levels[colName] = self.levels[colName]
   end

   -- convert t from 2D to 1D only if 1 column name supplied
   if #colNames == 1 then
      vp(1, 'only 1 column name')
      local newT = torch.Tensor(t:size(1))
      for i = 1, newT:size(1) do
         newT[i] = t[i]
      end
      t = newT
   end

   -- return tensor and levels
   vp(1, 'head t', head(t))
   vp(1, 'levels', levels)
   return t, levels
end

-- return new Dataframe containing all columns but ones specified
function Dataframe:dropColumns(seq)
   assert(type(seq) == 'table')
   local vp = makeVp(0, 'Dataframe:dropColumns')
   vp(1, 'columns to drop', seq)
   local retainedColumns = {}
   for _, currentColumnName in ipairs(self:columnNames()) do
      local toBeDropped = false
      for _, droppedColumnName in ipairs(seq) do
         if currentColumnName == droppedColumnName then
            toBeDropped = true
            vp(2, 'found column to be dropped', currentColumnName)
            break
         end
      end
      if not toBeDropped then
         vp(2, 'retaining column', currentColumnName)
         table.insert(retainedColumns, currentColumnName)
      end
   end
   vp(2, 'retained columns', retainedColumns)
   return self:onlyColumns(retainedColumns)
end

-- return new Dataframe containing only the specified columns
function Dataframe:onlyColumns(seq)
   assert(type(seq) == 'table')
   local vp = makeVp(0, 'Dataframe:onlyColumns')
   local newValues = {}
   local newLevels = {}
   for _, colName in ipairs(seq) do
      newValues[colName] = self.values[colName]
      newLevels[colName] = self.levels[colName]
   end
   vp(1, 'newValues keys', keys(newValues))
   vp(1, 'newLevels', newLevels)
   return Dataframe.new{values = newValues, levels=newLevels}
end

-- return new Dataframe containing only the specified rows
function Dataframe:onlyRows(seq)
   local vp = makeVp(0)
   local newValues = {}
   -- copy each key and the selected values
   for k, v in pairs(self.values) do
      local newSeq = {}
      for i, value in ipairs(v) do
         local s = seq[i]
         assert(type(s) == 'boolean',
                'seq[' .. i .. '] is not boolean')
         if s then
            newSeq[#newSeq + 1] = value
         end
      end
      newValues[k] = newSeq
   end
   -- do not recode the levels
   return Dataframe.new{values = newValues, levels=self.levels}
end

-- return new Dataframe containing only the specified row
function Dataframe:row(n)
   local vp = makeVp(0, 'Dataframe:row')
   vp(1, 'n', n)
   assert(math.floor(n) == n, 'n is not an integer')
   assert(n > 0, 'n is not a positive integer')
   assert(n <= self:nRows(), 'n exceeds number of rows')

   local newValues = {}
   for k, v in pairs(self.values) do
      local newSeq = {}
      newSeq[1] = v[n]
      newValues[k] = newSeq
   end
   
   vp(1, 'newValues', newValues)
   return Dataframe.new{values = newValues, levels = self.levels}
end

-- return new Dataframe containing only first few rows
-- MAYBE: allow n to be negative (to select last few rows)
function Dataframe:head(n)
   assert(type(n) == "number", 'n must be a number')
   assert(n >= 0, 'n must be non-negative')

   -- return up to n values in a sequence
   local function head(seq)
      local result = {}
      for i, v in ipairs(seq) do
         if i > n then return result end
         result[i] = v
      end
      return result
   end

   local newValues = {}
   for k, v in pairs(self.values) do
      newValues[k] = head(v)
   end

   local newLevels = {}
   for k, v in pairs(self.levels) do
      newLevels[k] = v  -- return all the levels, not the first n
   end

   return Dataframe.new{values = newValues, levels=newLevels}
end

-- return values in a specified column
function Dataframe:column(colName)
   return self.values[colName]  -- may return nil and that's OK
end

-- mutate by adding or changing a column
-- only add number and string columns, not factor columns
function Dataframe:addColumn(colName, values)
   if type(colName) ~= 'string' then error('colName must be a string') end
   if type(values) ~= 'table' then error('values must be a sequence') end
   for _, existingValue in pairs(self.values) do
      if #values ~= #existingValue then
         error('values must have same length as existing values')
      end
      break
   end

   self.values[colName] = values
   return self
end

-- mutate by dropping a column
function Dataframe:dropColumn(colName)
   if type(colName) ~= 'string' then error('colName must be a string') end
   if self.values[colName] == nil then
      error('column to be deleted must exist')
   end
   self.values[colName] = nil
   -- don't drop the level, as determining if a column shares levels requires
   -- extra work for a case that won't come up often
   return self
end

-- df1, df2 = df:split(fractionToDf1)
-- split rows randomly into two new Dataframes
function Dataframe:split(fractionToDf1)
   local vp = makeVp(0, 'Dataframe.split')
   vp(1, 'self is ' .. self:nRows() .. ' x ' .. self:nCols())
   vp(1, 'fractionToDf1', fractionToDf1)
   assert(0 <= fractionToDf1 and fractionToDf1 <= 1, 
          'fractionToDf1 is not in [0,1]')

   local inFirst = {}
   local inSecond = {}
   for i = 1, self:nRows() do
      local selected =  torch.uniform(0, 1) < fractionToDf1
      table.insert(inFirst, selected)
      table.insert(inSecond, not selected)
   end
   vp(2, 'inFirst', inFirst)
   vp(2, 'inSecond', inSecond)

   local df1 = self:onlyRows(inFirst)
   local df2 = self:onlyRows(inSecond)
      
   vp(1, 'df1 is ' .. df1:nRows() .. ' x ' .. df1:nCols())
   vp(1, 'df2 is ' .. df2:nRows() .. ' x ' .. df2:nCols())
   assert(df1:nRows() + df2:nRows() == self:nRows())
   return df1, df2
end

--------------------------------------------------------------------------------
-- AUXILLARY FUNCTION newEmpty (a constructor)
--------------------------------------------------------------------------------

-- construct an empty Dataframe
function Dataframe.newEmpty()
   return Dataframe.new{values = {}, levels = {}}
end

--------------------------------------------------------------------------------
-- AUXILLARY FUNCTION newFromFile2 (a constructor)
--------------------------------------------------------------------------------

-- construct Dataframe from content of file, when you know the types of columns
--
-- ARG: a table with these keys and values
--
-- file: string, path to file
-- 
-- nRows: integer, default -1
-- the maximum number of data rows to read. A negative value indicates that
-- all data rows are to be read.
--
-- sep: string, default ","
-- the field separator character. Each line is read as a string and split
-- using this string. The split determines the fields in the line.
--
-- naString: string, default ""
-- strings with these values are interpretted as missing. Missing values are
-- represented as the value Dataframe.NA. When a Dataframe is converted
-- to a Tensor with method asTensor, the Dataframe.NA values are converted
-- to NaN values.
--
-- skip: integer, default 0
-- Number of lines in the file that are skipped before beginning to process
-- the data.
--
-- factorColumns: seq on {string}
-- names of columns (from header) to be read as factors

-- numberColumns: seq on {string}
-- names of columns (from header) to be read as strings
-- if a number field in the file is not NA or a number, an error is raised
--
-- stringColumns: seq on {string}
-- names of columns (from header) to be read as factors
--
-- verbose: integer, default 0
--   0 ==> no printing 
--   1 ==> print args and result and keep alive messages
--   2 ==> print intermediate values
--
-- RETURNS: a Dataframe
function Dataframe.newFromFile2(t)
   if t == nil then error('argument (a table) must be supplied') end
   local arg = {}
   arg.file = t.file or error('must supply a file name')
   arg.nRows = t.nRows or -1  -- -1 ==> no limit
   arg.sep = t.sep or ','
   arg.skip = t.skip or 0
   arg.naString = t.naString or ''
   arg.factorColumns = t.factorColumns or {}
   arg.numberColumns = t.numberColumns or {}
   arg.stringColumns = t.stringColumns or {}
   arg.verbose = t.verbose or 0
   
   local vp = makeVp(arg.verbose, 'Dataframe.newFromFile2')

   vp(1, 'Dataframe.newFromFile2 arg', arg)

   local f, err = io.open(arg.file, 'r')
   if f == nil then 
      error('unable to open file ' .. arg.file .. ' message=' .. err) 
   end

   -- skip initial records
   while arg.skip > 0 do
      local record = f:read()
      if record == nil then 
         error('end of file while skipping initial records')
      end
      arg.skip = arg.skip - 1
   end

   -- read and parse header
   local header = f:read()
   if header == nil then error('did not find a header') end
   vp(1, 'header', header)

   local headerFieldPosition = {}
   for i, headerField in ipairs(splitString(header, arg.sep)) do
      headerFieldPosition[headerField] = i
   end

   vp(1, 'headerFieldPosition', headerFieldPosition)

   -- create allColumns and isNumberColumn
   -- check that user's column names actually exist
  
   local function assureInHeader(column)
      if headerFieldPosition[column] == nil then
         error('column ' .. column .. ' is not in the header')
      end
   end

   local allColumns = {}
   for _, column in ipairs(arg.factorColumns) do
      table.insert(allColumns, column)
      assureInHeader(column)
   end
   local isNumberColumn = {}
   for _, column in ipairs(arg.numberColumns) do
      table.insert(allColumns, column)
      isNumberColumn[column] = true
      assureInHeader(column)
   end
   for _, column in ipairs(arg.stringColumns) do
      table.insert(allColumns, column)
      assureInHeader(column)
   end


   vp(2, 'allColumns', allColumns)

   local values = {}
   for _, column in ipairs(allColumns) do
      values[column] = {}  -- initialize sequences
   end

   -- read the records
   -- convert naString to Dataframe.NA
   -- attempt to convert number columns to numbers
   local nRead = 0  -- count number read
   while true do
      local record = f:read()
      if record ~= nil then
         nRead = nRead + 1
      end
      if record == nil or (arg.nRows >= 0 and nRead > arg.nRows) then
         break  -- at EOF or record limit
      end
      vp(2, 'record', record)
      if arg.verbose >= 1 and nRead % 100000 == 0 then
         print('data record ' .. nRead .. ' = ' .. record)
      end
      -- accumulate values for all specified columns
      local recordFields = splitString(record, arg.sep)
      for _, column in ipairs(allColumns) do
         local i = headerFieldPosition[column]
         local value = recordFields[i]
         if value == arg.naString then
            value = Dataframe.NA
         elseif isNumberColumn[column] then
            local maybeNumber = tonumber(value)
            if maybeNumber == nil then
               vp(0, 'data record ' .. nRead .. 
                     ' field ' .. column ..
                     ' non-number value', value)
               error('data record ' .. nRead .. 
                     ' field ' .. column ..
                     ' has non-numeric value')
            else
               value = maybeNumber
            end
         end
         table.insert(values[column], value)
      end
      vp(3, 'recordFields', recordFields)
      vp(3, 'accumulated string values', values)
   end
   vp(1, string.format('read %d data records', nRead))
   --vp(2, 'accumulated string values', values)
   vp(2, 'string values for HEATING.CODE', values['HEATING.CODE'])
   collectgarbage()

   -- all the columns of interest are stored as string in values[column]


   -- convert factor columns (now strings) to factors
   -- NOTE that NA values are already represented as Dataframe.NA
   vp(1, 'converting strings to factors in factor columns')
   local levels = {}
   for _, column in ipairs(arg.factorColumns) do
      vp(2, 'factor column name', column)
      local indicesSeq, levelsSeq = asFactor(values[column],
                                               Dataframe.NA)
      vp(2, 'indices', indicesSeq)
      vp(2, 'levels', levelsSeq)
      values[column] = indicesSeq
      levels[column] = levelsSeq
   end
   vp(2, 'values', values)
   vp(2, 'levels', levels)
   collectgarbage()
   
   local result = Dataframe.new{values = values, levels = levels}
   if arg.verbose >= 1 then
      print('Dataframe.newFromFile result')
      result:print{n=5, levels=5}
   end
   return result
end

   
   

------------------------------------------------------------------------------- 
-- AUXILLARY FUNCTION newFromFile (a constructor)
--------------------------------------------------------------------------------

-- construct a Dataframe containing content of file
-- 
-- ARG: a table with these keys and values
-- 
-- file: string, path to file
-- 
-- header: boolean, default true
-- if true the file is assumed to have a header in the first record. 
-- The fields in the header become the names of the columns
--
-- nRows: integer, default -1
-- the maximum number of data rows to read. A negative value indicates that
-- all data rows are to be read.
--
-- sep: string, default ","
-- the field separator character. Each line is read as a string and split
-- using this string. The split determines the fields in the line.
--
-- stringsAsFactors: boolean, default true, required to be true for now.
-- Columns that are not all numbers or missing values or considered
-- columns of strings. If this argument is true, a column of strings is
-- converted into positive integers or NaNs (for missing values). The 
-- positive integers are indices into a level table with the same name as
-- the name of the column. For example, if a columns of strings named
-- "direction" contains "east", "west", "east", "north", then
-- get("direction", 1) and get("direction", 3) both have value 1 and
-- level("direction", 1) has value "east".
-- NOTE: in R, the level name strings are sorted. Here they are not.
--
-- naStrings: seq of string, default {"NA", ""}
-- strings with these values are interpretted as missing. Missing values are
-- represented as the value Dataframe.NA. When a Dataframe is converted
-- to a Tensor with method asTensor, the Dataframe.NA values are converted
-- to NaN values.
--
-- skip: integer, default 0
-- Number of lines in the file that are skipped before beginning to process
-- the data.
--
-- verbose: integer, default 0
--   0 ==> no printing 
--   1 ==> print args and result and keep alive messages
--   2 ==> print intermediate values
--
-- RETURNS: a Dataframe
function Dataframe.newFromFile(t)
   if t == nil then error('argument (a table) not supplied') end
   --print('t'); print(t)
   if t == nil then
      t = {}
   end
   local arg = {}
   arg.file = t.file or error('must supply file argument')
   arg.header = t.header or true
   arg.nRows = t.nRows or -1   -- -1 ==> no limit
   arg.sep = t.sep or ","
   if t.stringsAsFactors == nil then
      arg.stringsAsFactors = true
   else
      arg.stringsAsFactors = t.stringsAsFactors
   end
   arg.naStrings = t.naStrings or {"NA", ""}
   arg.skip = t.skip or 0
   arg.verbose = t.verbose or 0

   local vp = makeVp(arg.verbose)

   vp(1, 'Dataframe.newFromFile arguments after defaults set', arg)

   -- current implementation implements a subset of possible arguments
   if not arg.header then error('for now, must have a header') end
   
   -- open file
   local f, error = io.open(arg.file, "r")
   if f == nil then error('unable to open file ' .. arg.file) end

   -- skip initial records
   while arg.skip > 0 do
      local record = f:read()
      if record == nil then 
         error('end of file while skipping initial records')
      end
      arg.skip = arg.skip - 1
   end

   -- read header
   local header = f:read()
   if header == nil then
      error('file is empty')
   end
   vp(2, 'header = ' .. header)
   local headerFields = splitString(header, arg.sep)
   local nFields = #headerFields
   vp(2, 'headerFields', headerFields)
   if (nFields == 0) then error('no fields in header') end

   -- replace empty header fields with 'V n' (as does R's readTable)
   local missingHeaderIndex = 0
   for i, headerField in ipairs(headerFields) do
      if headerField == '' then
         missingHeaderIndex = missingHeaderIndex + 1
         headerFields[i] = 'V ' .. missingHeaderIndex
      end
   end

   local headerFieldsTable = {}
   for _, headerField in ipairs(headerFields) do
      headerFieldsTable[headerField] = true
   end

   -- build initial empty values sequences
   local values = {}
   for _, headerField in ipairs(headerFields) do
      values[headerField] = {}
   end
   vp(2, 'initial values', values)

   local function isNA(value)
      for _, naString in ipairs(arg.naStrings) do
         if naString == value then
            return true
         end
      end
      return false
   end

   local function isNumber(value)
      if tonumber(value) then
         return true
      else
         return false
      end
   end

   -- should we use the colName
   local function useColumnName(fieldName)
      if headerFieldsTable[fieldName] then
         return true
      else
         return false
      end
      --return arg.colNames == nil or sequenceContains(arg.colNames, fieldName)
   end
   
   local values = {}
   local valuesAreAlwaysNumbersOrNA = {}
   local function appendToValues(record)
      vp(3, 'appending record', record)
      local recordFields = splitString(record, arg.sep)
      if #recordFields ~= nFields then
         print("record = " .. record)
         print('recordFields'); print(recordFields)
         error(string.format('data record %d has %d fields,' .. 
                             'not %d as the header did',
                             nRead, #recordFields, nFields))
      end

      -- append to values sequences
      -- keep track of if values are always NA or numbers
      for fieldIndex, fieldName in ipairs(headerFields) do
         if useColumnName(fieldName) then
            local fieldValue = recordFields[fieldIndex]
            
            -- make sure the values[fieldName] sequence exists
            if not values[fieldName] then
               values[fieldName] = {}
            end
            
            -- append to values[fieldName] sequence
            local na = isNA(fieldValue)
            local num = isNumber(fieldValue)
            
            if na then
               table.insert(values[fieldName], Dataframe.NA)
            else
               table.insert(values[fieldName], fieldValue)  -- keep as string
            end
            
            -- initialize valuesAreAlwaysNumbersOrNA
            if valuesAreAlwaysNumbersOrNA[fieldName] == nil then
               valuesAreAlwaysNumbersOrNA[fieldName] = true
            end
            
            vp(3, 'na', na)
            vp(3, 'num', num)
            if na or num then
               -- no nothing
            else
               valuesAreAlwaysNumbersOrNA[fieldName] = false
            end
            
            vp(3, 'after fieldName', fieldName)
            vp(3, 'updated values', values)
            vp(3, 
               'updated valuesAreAlwaysNumbersOrNA', 
               valuesAreAlwaysNumbersOrNA)
         end
      end
   end -- appendToValues

   -- return factorValues (seq of integer), stringLevels (seq of string)
   local function asFactor(stringValues) -- arg is seq of string
      vp(3, 'asFactor stringValues', stringValues)
      local levelOf = {}
      local nextLevelIndex = 0

      local function replacementValue(value)
         if value == Dataframe.NA then
            return Dataframe.NA
         else
            local level = levelOf[value]
            if level then 
               return level 
            end
            nextLevelIndex = nextLevelIndex + 1
            levelOf[value] = nextLevelIndex
            return nextLevelIndex
         end
      end

      local levelNumberValues = {}
      for _, value in ipairs(stringValues) do
         table.insert(levelNumberValues, replacementValue(value))
      end

      -- convert the levelOf table to a sequence
      local seq = {}
      for stringValue, levelNumber in pairs(levelOf) do
         seq[levelNumber] = stringValue
      end
      vp(3, 'asFactor levelNumberValues', levelNumberValues)
      vp(3, 'asFactor level seq', seq)
      return levelNumberValues, seq
   end -- asFactor

   -- read and parse data records
   local nRead = 0
   while true do
      local record = f:read()
      if record ~= nil then 
         nRead = nRead + 1 
         vp(2, "record = " .. record)
      end
      if record == nil or (arg.nRows >= 0 and nRead > arg.nRows) then
         -- stop and end of file or if have read enough records
         break
      end
      if arg.verbose >= 1 and nRead % 10000 == 0 then
         print('data record ' .. nRead .. '=' .. record)
      end
      local recordFields = splitString(record, arg.sep)
      if #recordFields ~= nFields then
         print("record = " .. record)
         print('recordFields'); print(recordFields)
         error(string.format('data record %d has %d fields,' .. 
                             'not %d as the header did',
                             nRead, #recordFields, nFields))
      end

      appendToValues(record)
      collectgarbage()
   end
   vp(2, 'values after initial reading pass', values)
   vp(2, 'valuesAreAlwaysNumbersOrNA', valuesAreAlwaysNumbersOrNA)

   -- convert all-numeric value sequences to sequences of number
   -- convert strings to level number, if arg.stringsAsFactors
   -- replace NAs with NaN
   -- build levels for other value sequences
   local levels = {}
   for colName, colValues in pairs(values) do
      vp(2, 'converting colName', colName)
      vp(2, 'colValues', colValues)

      if valuesAreAlwaysNumbersOrNA[colName] then
         -- convert numeric columns to numbers (they are presently strings)
         for i, value in ipairs(values[colName]) do
            if value == Dataframe.NA then
               values[colName][i] = Dataframe.NA
            else
               values[colName][i] = tonumber(value)
            end
         end
      elseif arg.stringsAsFactors then
         -- convert strings to factors, if that's what user asked
         factorValues, stringLevels = asFactor(values[colName])
         values[colName] = factorValues
         levels[colName] = stringLevels
      else
         -- keep the strings as strings (so do nothing)
      end
   end
   
   -- construct Dataframe and return
   local result = Dataframe.new{values = values, levels = levels}
   if arg.verbose >= 1 then
      print('Dataframe.newFromFile result')
      result:print{}
   end

   return result
end

--------------------------------------------------------------------------------
-- AUXILARY FUNCTION newFromMerge
--------------------------------------------------------------------------------

-- construct new data frame by merging two existing data frames on one field
function Dataframe.newFromMerge(t)
   local arg = {}
   arg.dfX = t.dfX or error('must supply dataframe x')
   arg.dfY = t.dfY or error('must supply dataframe y')
   arg.byX = t.byX or error('must supply column name byx')
   arg.byY = t.byY or error('must supply column name byy')
   arg.verbose = 0

   local vp = makeVp(arg.verbose)
   
   if false and arg.dfX:nRows() < arg.dfY:nRows() then
      return Dataframe.merge{dfX = arg.dfY, byX=arg.byY,
                             dfY = arg.dfY, byY=arg.byX}
   end

   -- build new values and levels
   local newValues = {}
   local newLevels = {}

   -- find values in common in the byX and byY columns
   -- values in data frames must be strings or numbers
   local function unique(t) 
      vp(3, 'unique t', t)
      local u = {}
      for key, value in pairs(t) do
         if type(value) == 'number' or type(value) == 'string' then
            u[value] = true
         end
      end
      vp(3, 'unique u', u)
      return u -- table of unique values in table t
   end

   local allXValues = unique(arg.dfX:column(arg.byX))
   local allYValues = unique(arg.dfY:column(arg.byY))
   if type(allXValues[1]) ~= type(allYValues[1]) then
      error('type X = ' .. type(allXValues[1]) ..
            '~= type Y = ' .. type(allYValues[1]))
   end

   local commonValues = {}
   for value, _  in pairs(allXValues) do
      if allYValues[value] then
         commonValues[value] = true
      end
   end

   vp(2, 'allXValues', allXValues)
   vp(2, 'allYValues',  allYValues)
   vp(2, 'commonValues', commonValues)
   
   local function alsoInY(xColName) 
      for _, yColName in ipairs(arg.dfY:columnNames()) do
         if xColName == yColName then
            return true
         end
      end
      return false
   end

   local function alsoInX(yColName)
      for _, xColName in ipairs(arg.dfX:columnNames()) do
         if yColName == xColName then
            return true
         end
      end
      return false
   end

   -- pre-determine row indices in X that are to be retained
   local xKeepRow = {}
   local xColumn = arg.dfX:column(arg.byX)
   vp(2, 'xColumn', xColumn)
   local n = arg.dfX:nRows()
   for i = 1, n do
      if commonValues[xColumn[i]] then
         xKeepRow[i] = true
      end
   end
   vp(2, 'xKeepRow', xKeepRow)
   
   -- examine each column in dfX, retaining rows that have a common value
   local newValues = {}
   local newLevels = {}
   vp(2, 'x column names', arg.dfX:columnNames())
   for _, xColName in ipairs(arg.dfX:columnNames()) do
      -- keep only rows that contain a common value
      local currentValue = arg.dfX:column(xColName)
      vp(2, 'currentValue', currentValue)
      local newValue = {}
      for i = 1, n do
         if xKeepRow[i] then
            newValue[#newValue + 1] = currentValue[i]
         end
      end
      vp(2, 'xColName', xColName)
      assert(type(xColName) == 'string', 'type=' .. type(xColname))
      vp(2, 'newValue', newValue)

      -- save rows to keep under correct name
      local newColumnName = ifelse(alsoInY(xColName),
                                   'x ' .. xColName,
                                   xColName)
      newValues[newColumnName] = newValue
      if arg.dfX:kind(xColName) == "factor" then
         newLevels[newColumnName] = arg.dfX.levels[xColName]
      end
   end
   vp(2, 'newValues after retaining dfX', newValues)
   vp(2, 'newLevels after retaining dfX', newLevels)

   -- pre-determine row indices in Y that are to be retained
   local yKeepRow = {}
   local yColumn = arg.dfY:column(arg.byY)
   local n = arg.dfY:nRows()
   for i = 1, n do
      if commonValues[yColumn[i]] then
         yKeepRow[i] = true
      end
   end
   vp(2, 'yKeepRow', yKeepRow)

   -- examine each column in dfY, retaining rows that have a common value
   for _, yColName in ipairs(arg.dfY:columnNames()) do
      local currentValue = arg.dfY:column(yColName)
      local newValue = {}
      for i = 1, n do
         if yKeepRow[i] then
            newValue[#newValue + 1] = currentValue[i]
         end
      end
      vp(2, 'yColName', yColName)
      vp(2, 'newValue', newValue)

      -- save new value under correct name
      local newColumnName = ifelse(alsoInX(yColName),
                                   'y ' .. yColName,
                                   yColName)
      vp(2, 'alsoInx', alsoInX(yColName))
      vp(2, 'newColumnName', newColumnName)
      newValues[newColumnName] = newValue
      if arg.dfY:kind(yColName) == "factor" then
         newLevels[newColumnName] = arg.dfY.levels[yColName]
      end
   end
   vp(2, 'newValues after retaining dfY', newValues)
   vp(2, 'newLevels after retaining dfY', newLevels)

   local result = Dataframe.new{values = newValues, levels = newLevels}
   if arg.verbose >= 1 then
      print('Dataframe.newFromMerge result')
      result:print()
   end
   return result
end

