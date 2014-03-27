-- SerializedTable.lua

if false then
   st = SerializedTable('path/to/file', format) -- format in {'ascii', 'binary'}
   err = st:load()  -- return string if fails to load
   st:save()
   value = st:get(key)
   st:set(key, value)
end

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

torch.class('SerializedTable')

-- ARGS
-- path   : string, path to file, file name is path.SerializedTable
-- format : string, either 'ascii' or 'binary'
function SerializedTable:__init(path, format)
   assert(type(path) == 'string')
   assert(type(format) == 'string')
   assert(format == 'ascii' or format == 'binary')

   self.path = path .. '.SerializedTable'
   self.format = format
   self.table = {}
end


-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------
   
-- attempt to load cache
-- RETURNS
-- err : nil or string
--       if string, contains error message
function SerializedTable:load()
   -- the torch.load() function doesn't give a good error message if the file
   -- does not exist.
   local handle, err = io.open(self.path, "r")
   if handle == nil then
      -- cache file does not exist
      return string.format('disk file %s does not exist', self.path)
   end
   handle:close()
   
   tableOption = torch.load(self.path, self.format)
   if type(tableOption) == 'table' then
      self.table = tableOption
      return nil
   else
      return string.format('file contains a serialized %s, not a serialized table', type(tableOption))
   end
end

-- save table to file in serialized format
function SerializedTable:save()
   torch.save(self.path, self.table, self.format)
end

-- return value in table
-- ARGS:
-- key : object, key in table
function SerializedTable:get(key)
   return self.table[key]
end

-- set key, value pair in table
-- ARGS:
-- key   : object, the key
-- value : object, the value
function SerializedTable:set(key, value)
   self.table[key] = value
end
