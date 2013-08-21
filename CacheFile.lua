-- CacheFile.lua

require 'Dataframe'
require 'isSequence'
require 'makeVp'

-- API overview
if false then
   cf = CacheFile{keyNames={'key1', 'key2'},
                  valueNames={'value1', 'value2'},
                  filePath='path/to/file'}

   -- storing and fetching from RAM
   -- type(keys) must be in {number, string}
   alreadyPresent = cf:store{keys={key1, key2}, values={value1, value2}}
   -- errors if keys are in table with different values

   valueSeq = cf:fetch{keys={key1, key2}}
   -- if not present, valueSeq == nil
   -- otherwise valueSeq[1] == value1, valueSeq[2] == value2, ...
   
   -- writing and reading to file system
   cf:write()
   cf:merge()   -- store entries in disk file into the cache
end

local CacheFile = torch.class('CacheFile')

function CacheFile:__init(t)
   local vp = makeVp(0, 'CacheFile:__init')
   vp(1, 
      'keyNames', t.keyNames, 
      'valueNames', t.valueNames, 
      'filePath', t.filePath)
   assert(type(t) == 'table', 'missing only argument, which should be a table')
   self.keyNames = t.keyNames
   self.valueNames = t.valueNames
   self.filePath = t.filePath
   
   -- validate args
   assert(type(self.keyNames) == 'table', 'keyNames is not a sequence')
   assert(type(self.valueNames) == 'table', 'valueNames is not a sequence')
   assert(type(self.filePath) == 'string', 'filePath is not a string')

   self.table = {}
end

local function writeFields(file, seq1, seq2Option)
   local vp = makeVp(0, 'writeFields')
   vp(1, 'file', file, 'seq1', seq1, 'seq2Option', seq2Option)
   local firstTime = true
   for _, value in ipairs(seq1) do
      if firstTime then
         firstTime = false
      else
         file:write(',')
      end
      file:write(value)
   end
   if seq2Option then
      for _, value in ipairs(seq2Option) do
         file:write(',')
         file:write(value)
      end
   end
   file:write('\n')
end
   
local function isSequenceOfValues(obj)
   if not isSequence(obj) then
      return false
   end
   for _, element in ipairs(obj) do
      if type(element) == 'table' then 
         return false
      end
   end
   return true
end

local function copySeq(seq)
   local newSeq = {}
   for i, element in ipairs(seq) do
      newSeq[i] = element
   end
   return newSeq
end

-- reduce to writeFields
local function writeValues(self, file, t, keys)
   local vp = makeVp(0, 'writeValues')
   vp(1, 'self', self, 'file', file, 't', t, 'keys', keys)
   assert(keys ~= nil)
   if #keys == #self.keyNames then
      writeFields(file, keys, self:fetch{keys=keys})
   else
      for k, v in pairs(t) do
         local newKeys = copySeq(keys)
         table.insert(newKeys, k)
         vp(2, 'k', k, 'v', v, 'newKeys', newKeys)
         writeValues(self, file, v, newKeys)
      end
   end
end

function CacheFile:write()
   local vp = makeVp(0, 'CacheFile:write')
   vp(1, 
      'self.filePath', self.filePath,
      'self.keyNames', self.keyNames,
      'self.valueNames', self.valueNames,
      'self.table', self.table)
   local file, msg = io.open(self.filePath, 'w+') -- + ==> erase previous data
   if file == nil then
      error('io.open error = ' .. msg)
   end
   
   -- write csv header
   writeFields(file, self.keyNames, self.valueNames)

   -- write each data record
   writeValues(self, file, self.table, {})

   file:close()
end

-- return entries in row from designated columns as a sequence
-- convert entries from strings to numbers where possible
local function rowEntries(df, rowIndex, columNames)
   local vp = makeVp(0, 'rowEntries')
   vp(1,
      'df', df,
      'rowIndex', rowIndex,
      'columnNames', columnNames)
   local seq = {}
   for _, columnName in ipairs(columNames) do
      local value = df:get(columnName, rowIndex)
      local maybeNumberValue = tonumber(value)
      if maybeNumberValue then
         table.insert(seq, maybeNumberValue)
      else
         table.insert(seq, value)
      end
   end
   return seq
end

function CacheFile:merge()
   local vp = makeVp(0, 'CacheFile:merge')
   vp(1, 
      'self.keyNames', self.keyNames,
      'self.valueNames', self.valueNames)

   local file, msg = io.open(self.filePath, 'r')
   if file == nil then
      vp(0, 'WARNING: cache file does not exist. Treated as empty file')
      return
   end

   -- build seq of all column names
   local stringColumns = copySeq(self.keyNames)
   for _, name in ipairs(self.valueNames) do
      table.insert(stringColumns, name)
   end

   -- read csv file into a dataframe where each column is a string
   local df = Dataframe.newFromFile2{file=self.filePath,
                                     sep=',',
                                     stringColumns=stringColumns}
   vp(2, 'df', df)

   -- store each row into a cache
   vp(2, 'df:nRows()', df:nRows())
   for rowIndex = 1, df:nRows() do
      vp(2, 'self.keyNames', self.keyNames)
      local keys = rowEntries(df, rowIndex, self.keyNames)
      local values = rowEntries(df, rowIndex, self.valueNames)

      vp(2, 'keys', keys, 'values', values)
      self:store{keys=keys, values=values}
   end
end
         

local function fetch(table, keys, index)
   local key = keys[index]
   if index < #keys then
      local value = table[key]
      if value == nil then
         return nil
      else
         return fetch(value, keys, index + 1)
      end
   else 
      return table[key]
   end
end      
      

function CacheFile:fetch(t)
   assert(type(t) == 'table', 'missing only arg, table with 2 keys')

   -- validate args
   local keys = t.keys
   assert(type(keys) == 'table', 'keys is not a sequence')
   assert(#keys == #self.keyNames, 'wrong number of keys')

   return fetch(self.table, keys, 1)
end

local function eachEqual(a, b)
   for i, aElement in ipairs(a) do
      if b[i] ~= aElement then
         return false
      end
   end
   return true
end

-- are two sequences identical?
local function allEqual(a, b)
   return #a == #b and eachEqual(a,b)
end

-- return
-- alreadyPresent : boolean, true iff all keys are in the table 
--                  with specified values
local function store(table, keys, index, values)
   local vp = makeVp(0, 'store')
   vp(1, '\n********** store')
   vp(1, 'table', table, 'keys', keys, 'index', index, 'values', values)
   local key = keys[index]
   local value = table[key]
   vp(2, 'key', key, 'value', value)
   -- boolean keys do not allow for printing, so prevent them
   assert(type(key) == 'number' or type(key) == 'string')
   if index < #keys then
      if value == nil then
         table[key] = {}
         return store(table[key], keys, index + 1, values)
      else
         return store(value, keys, index + 1, values)
      end
   else
      if value == nil then
         table[key] = values
         return false
      else
         if allEqual(value, values) then
            return true
         else
            vp(1, 'values to be inserted', value)
            vp(1, 'values in table already', values)
            vp(1, 'keys', keys)
            error('keys in table with different value')
         end
      end
   end
end

function CacheFile:store(t)
   local vp = makeVp(0, 'CacheFile:store')
   assert(type(t) == 'table', 'missing only arg, table with 2 keys')

   -- validate args
   local keys = t.keys
   local values = t.values
   vp(1, 'keys', keys, 'values', values, 'self.table', self.table)
   assert(type(keys) == 'table', 'keys is not a sequence')
   assert(type(values) == 'table', 'values is not a sequence')
   assert(#keys == #self.keyNames, 'wrong number of keys')
   assert(#values == #self.valueNames, 'wrong number of values')

   local alreadyPresent = store(self.table, keys, 1, values)
   vp(2, 'alreadyPresent', alreadyPresent)
   vp(2, 'after store self.table', self.table)
   
   vp(1, 'alreadyPresent', alreadyPresent, 'final self.table', self.table)
   return alreadyPresent
end
   