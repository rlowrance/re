-- TableCached.lua
-- A lua table that can be written to a CSV file and read back in

require 'fileAssureExists'
require 'makeVp'

-- API overview
if false then
   tc = TableCached('path/to/file', 'ascii')  -- create file if necessary

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

function TableCached:__init(filePath, format)
   local vp = makeVp(1, 'TableCached:__init')
   vp(1, 'filePath', filePath, 'format', format)

   validateAttributes(filePath, 'string')

   validateAttributes(format, 'string')
   assert(format == 'ascii' or format == 'binary')

   -- initialize instance variables
   self.filePath = filePath
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
   local vp = makeVp(2, 'TableCached:replaceWithFile')
   vp(1, 'self', self)
   -- guard against cache file not existing
   if fileExists(self.filePath) then
      vp(2, 'cache file exists')
      self.table = torch.load(self.filePath, self.format)
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
   torch.save(self.filePath, self.table, self.format)
end

