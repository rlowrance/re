-- Log.lua
-- define class Log: logging and printing to stderr as side effect
-- periodically close and reopen the log

require 'torch'

-- API Overview
if false then
   local log = Log('path/to/log/file')  -- time stamp each entry
   local log = Log('path', false)       -- don't time stamp each entry

   log:log('format', ...)   -- like print(string.format(format, ...))
   log:log('string')

   log:logTable('string', table) -- log each entry

   log:close()
end

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

local Log = torch.class('Log')

function Log:__init(pathToFile, writeTimeStamp)
   local logFile = assert(io.open(pathToFile, 'w'),
                          'Log: unable to open log file')
   self.logFile = logFile
   self.nRecordWritten = 0
   self.nRecordsBeforeFlush = 100
   self.pathToFile = pathToFile

   if writeTimeStamp == nil or  writeTimeStamp == true then
      self.stamp = true
   elseif writeTimeStamp == false then
      self.stamp = false
   else
      error('invalid writeTimeStamp = ' .. 
            tostring(writeTimeStamp))
   end
end -- _init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function Log:log(format, ...)
   -- compose the record
   local s
   if ... == nil then 
      s = format
   else
      s = string.format(format, ...)
   end

   -- write the record
   self:_writeRecord(s)

   -- periodically close and reopen the log file
   self.nRecordsWritten = self.nRecordWritten + 1
   if self.nRecordsWritten > self.nRecordsBeforeFlush then
      self.logFile:_writeRecord('flushing log file to disk\n')
      self.logfFile = assert(io.open(pathToFile, 'a'),
                             'Log: unable to reopen log file in append mode')
   end
end -- log

function Log:logTable(name, table)
   -- log elements of table
   self:log(name)
   for key, value in pairs(table) do
      self:log(' [%q] = %q', tostring(key), tostring(value))
   end
end -- logTable

function Log:close()
   self.logFile:close()
end -- close

--------------------------------------------------------------------------------
-- PRIVATE METHODS
--------------------------------------------------------------------------------


function Log:_maybeTimeStamp()
   -- return time stamp   if self.stamp is true
   -- return empty string if self.stamp is false
   if self.stamp then
      return self:_timeStamp() .. ' '
   else
      return ''
   end
end -- _maybeTimeStamp

function Log:_timeStamp()
   -- return time stamp as string YYYY-MM-DD HH:MM
   local t = os.date('*t')
   return string.format('%4d-%02d-%02d %02d:%02d',
                        t.year, t.month, t.day, t.hour, t.sec)
end -- _timeStamp

-- write record s to log file and to stderr
-- supply a new line
function Log:_writeRecord(s)
   s = self:_maybeTimeStamp() .. s .. '\n'
   self.logFile:write(s)
   io.stderr:write(s)
end -- _writeRecord   
