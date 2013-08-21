-- read a slice of a file
-- def: slice : slice n of m slices, possibly every record

-- API overview
if false then
   sr = SliceReader(openFile, n, m)
   repeat -- process every record in slice n of m slices
      local record = sr:next()
      if record then
         -- record does not have the final \n
         processRecord(record)
      end
   until record == nil
   local function action(record) end
   local nRecordsProccess = sr:forEachRecord(action)
end

require 'makeVp'
require 'validateAttributes'

local SliceReader = torch.class('SliceReader')

-- construction
-- ARGS:
-- openFile : file for reading, already open
-- n        : integer > 0, the nth slice is read
-- m        : integer >= n, the file is considered to have m slices
function SliceReader:__init(openFile, n, m)
   local vp = makeVp(0, 'SliceReader:__init')
   validateAttributes(openFile, 'file')
   validateAttributes(n, 'number', 'integer', '>', 0) -- no way to test if open
   validateAttributes(m, 'number', 'integer', '>=', n)
   
   self.openFile = openFile
   self.n = n
   self.m = m

   self.cycle = 0
   vp(1, 'self', self)
end

-- return next record (without the final \n) or nil if at end of file
function SliceReader:next()
   local vp = makeVp(0, 'SliceReader:next')
   vp(1, 'self', self)
   local record = nil
   repeat
      record = self.openFile:read('*l')  -- discard final \n
      vp(2, 'record', record)
      if record == nil then
         vp(1, 'result is nil')
         return nil
      end
      self.cycle = self.cycle + 1
      if self.cycle > self.m then
         self.cycle = 1
      end
      vp(2, 'self.cycle', self.cycle)
   until self.cycle == self.n

   vp(1, 'result', record)
   return record
end


-- apply function to each record in the slice, return number of records actioned
function SliceReader:forEachRecord(action)
   validateAttributes(action, 'function') 
   local nActions = 0
   repeat -- process every record in slice n of m slices
      local record = self:next()
      if record then
         -- record does not have the final \n
         action(record)
         nActions = nActions + 1
      end
   until record == nil
   return nActions
end
