-- TableCached.lua
-- A lua table that can be written to a pair of CSV files and read back in

require 'fileAssureExists'
require 'makeVp'

-- API overview
if false then
   tc = TableCached('path/to/base_file_name', 'ascii')  -- create file if necessary

   -- storing and fetching keys and values from the cache
   tc:store(123, {'abc', true})  -- key, value
   tc:store('x', 45.6)

   seq = tc:fetch(123) -- seq == {'abc', true}
   x = tc:fetch('x')   -- seq == 45.6

   -- iterating over elements
   for k, v in tc:pairs() do 
      print(k) print(v) 
   end

   -- reading and writing to associated disk file 
   -- in binary serialization format
   tc:writeToFile()
   if tc:replaceWithFile() then
      state = 'file was read; its content replaced the table'
   end

   -- empty the table
   tc:reset()
end

-- construction
local TableCached = torch.class('TableCached')

-- create and initialize object
-- ARGS:
-- basePath : string, base path to file that will hold the cache on disk
--            the writeToFile() method writes alternates between writing two files
--              basePath .. '.' .. format
--              basePath .. '-alternative' .. '.' .. format
-- format   : string in {'ascii', 'binary'} format of file on disk
function TableCached:__init(basePath, format)
   local vp = makeVp(0, 'TableCached:__init')
   vp(1, 'basePath', basePath, 'format', format)

   validateAttributes(basePath, 'string')

   validateAttributes(format, 'string')
   assert(format == 'ascii' or format == 'binary')

   -- initialize instance variables
   self.filePaths = {}
   self.filePaths[1] = basePath .. '.' .. format
   self.filePaths[2] = basePath .. '-alternative' .. '.' .. format
   self.nextFilePathIndex = 1
   self.format = format
   self.table = {}
end

-- fetch
function TableCached:fetch(key)
   return self.table[key]
end

-- pairs
function TableCached:pairs()
   return pairs(self.table)
end

-- replaceWithFile
function TableCached:replaceWithFile()
   local vp = makeVp(0, 'TableCached:replaceWithFile')
   vp(1, 'self', self)
   -- guard against cache file not existing
   local filePath = self.filePaths[1]
   if fileExists(filePath) then
      vp(2, 'cache file exists')
      self.table = torch.load(filePath, self.format)
      return true
   else
      return false
   end   
end

-- reset
function TableCached:reset()
   self.table = {}
end

-- store
function TableCached:store(key, value)
   local vp = makeVp(0, 'TableCached:store')
   vp(1, 'key', key, 'value', value)
   self.table[key] = value
end

-- writeToFile
function TableCached:writeToFile()
   local filePath = self.filePaths[self.nextFilePathIndex]
   if self.nextFilePathIndex == 1 then
      self.nextFilePathIndex = 2
   else
      self.nextFilePathIndex = 1
   end

   torch.save(filePath, self.table, self.format)
end

