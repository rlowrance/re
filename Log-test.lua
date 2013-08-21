-- Log-test.lua
-- unit test

require 'all'

tester = Tester()
test = {}

--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------

function test.flush()
   -- write enough records to cause a flush
   local path = '/tmp/Log-test:test.flush'
   local log = Log(path)
   local n = log.nRecordsBeforeFlush
   assert(n)
   for i = 1, n + 1 do
      log:log('record number %d', i)
      if i > n then
         print('check that at least' .. 
               tostring(n) .. 
               ' log file records written')
         return 1/ 0
      end
   end
end -- test.flush 

function writeLog(log)
   -- write various data type to log, as these are handle specially
   -- test writing of string
   log:log('announcement')
   -- test writing as if a call to string.format
   log:log('%d = %f', 1, 2)
   -- test that table are properly displayed
   local table = {}
   table.a = 1
   table.b = 2
   log:logTable('table', table)
end

function test.useTimeStamps()
   local path = '/tmp/Log-test:test.useTimeStamps'
   local log = Log(path)
   print('should see time stamps')
   writeLog(log)
   log:close()
end

function test.noTimeStamps()
   local path = '/tmp/Log-test:test.noTimeStamps'
   local useTimeStamps = true
   local log = Log(path, not useTimeStamps)
   print('should not see time stamps')
   writeLog(log)
   log:close()
end

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

tester:add(test)
local verbose = true
tester:run(verbose) 
print('Examine output to determine if I ran correctly')