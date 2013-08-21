-- timing-test-csv-vs-lua.lua
-- compare execution times to read file via Csv class and as a lua data file
-- the test file is the hpivalues file from laufer

--[[ 
Generates an error when run on hpivalues-truncated, which contains
1 million lines; Does not error if hpivalues-truncated has only 100,000 lines.

laufer-2012-03-hpi-values $torch ../../src.git/lua/timing-test-csv-vs-lua.lua
Try the IDE: torch -ide
Type help() for more info
Torch 7.0  Copyright (C) 2001-2011 Idiap, NEC Labs, NYU
[program started on Tue 01 May 2012 08:08:58 PM EDT]
[command line arguments]
rundir    timing-test-csv-vs-lua
suffix    
[----------------------]
torch-qlua: constant table overflow
stack traceback:
	[C]: ?
	[C]: in function 'dofile'
	../../src.git/lua/timing-test-csv-vs-lua.lua:28: in function 'testLua'
	../../src.git/lua/timing-test-csv-vs-lua.lua:33: in main chunk
stack traceback:
	[C]: ?
	[C]: in function 'dofile'
	../../src.git/lua/timing-test-csv-vs-lua.lua:28: in function 'testLua'
	../../src.git/lua/timing-test-csv-vs-lua.lua:33: in main chunk
   --]]

require 'csv'

-- non-commandline parametes
functionName = 'd'  -- for data

cmd= torch.CmdLine()
cmd:text('Convert csv file to lau program file')
cmd:text()
cmd:option('-suffix', '', 'optional suffix for file name; run just one if supplied')
cmd:text()

params = cmd:parse(arg)

params.rundir = cmd:string('timing-test-csv-vs-lua', params, {})

-- create log file
os.execute('mkdir -p ' .. params.rundir)
cmd:log(params.rundir .. '/log.txt', params)

------------------------------ lua file

function testLua()
   function d(record) print(record) end
   dofile 'hpivalues-truncated.lua'
end

if suffix ~= '' or suffix == 'lua' then
   local timer = torch.Timer()
   testLua()
   print('lua time', timer:time())
end

-----------------------------  csv file

function testCsv()
   local timer = torch.Timer()
   local csv = Csv('hpivalues.txt')
   local header = csv:read()
   while true do
      local dataStrings = csv:read()
      if not dataStrings then break end
   end
   csv:close()
end

if suffix ~= '' or suffix == 'txt' then
   local timer = torch.Timer()
   testCsv()
   print('csv time', timer:time())
end


print('Finished')

   

