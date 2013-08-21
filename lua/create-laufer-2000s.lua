-- create-laufer-2000s.lua
-- NOTE: ALL OF LAUFER'S ESTIMATES ARE FOR THIS TIME PERIOD
-- Hence this program is useless.
-- reduce the laufer hpivalues.txt file to one containing just estimates
-- that occured in 2000, 2001, ..., 20009

require 'csvutils'
require 'CmdLine2'


--------------------------------------------------------------------------------
-- handle command line
--------------------------------------------------------------------------------

cmd = CmdLine2()
cmd:text('reduce Laufer hpivalue.txt to just those for the 2000s')
cmd:text()
cmd:text('Run from lua directory')
cmd:text()
cmd:text('Options')
cmd:option('-dataDir', '', 'Path to data directory')

-- parse command line
params = cmd:parse(arg)
print('params', params)

assert(params.dataDir ~= '')

--------------------------------------------------------------------------------
-- establish paths to directories and files
--------------------------------------------------------------------------------

dirLaufer = params.dataDir .. 'laufer-2012-03-hpi-values/'

fileLaufer = dirLaufer .. 'hpivalues.txt'
fileOutput = dirLaufer .. 'hpivalues-2000s.csv'

--------------------------------------------------------------------------------
-- start logging
--------------------------------------------------------------------------------

do
   print(cmd:string('abc', params, {}))
   local dirLog = 
      dirLaufer ..  
      cmd:string('create-laufer-2000s', params, {dataDir = true}) .. '/'
   os.execute('mkdir ' .. dirLog)  -- create directory if it does not exist

   local pathLogFile = dirLog .. 'log.txt'
   print('pathLogFile', pathLogFile)
   cmd:log(pathLogFile, params)

   print()
   print('Directories used')
   print('dirObs', dirObs)
   print('dirAnalysis', dirAnalysis)

   print()
   print('Files used')
   print('fileLaufer', fileLaufer)
   print('fileOutput', fileOutput)

end

--------------------------------------------------------------------------------
-- read Laufer's estimates; write just those in 2000s
--------------------------------------------------------------------------------

outfile = io.open(fileOutput, 'w')
assert(outfile, outfile)

-- return true if data string begins with 200
local function in2000s(date)
   if string.match(date, '200') then
      return true
   else
      return false
   end
end

local function readEstimates(tag, inFilePath, pattern)
   local countWritten = 0
   local file = io.open(inFilePath, 'r')
   if not file then
      error('file did not open; inFilePath=' .. inFilePath)
   end
   local header = file:read('*l')
   outfile:write(header) -- preserve the existing header
   outfile:write('\n')
   for line in file:lines('*l') do
      local apn, date, estimate = string.match(line, pattern)
      -- check that all values were parsed
      assert(apn, 'not parsed: ' .. line)
      assert(date, 'not parsed: ' .. line)
      assert(estimate, 'not parsed: ' .. line)
      if in2000s(date) then
	 outfile:write(line)
	 outfile:write('\n')
	 countWritten = countWritten + 1
	 -- print first 10 records saved, for error checking of the pattern
	 if countWritten <= 10 then
	    print('read', apn, date, estimate)
	    print('wrote', line)
	 end
      end
   end
   file:close()
   print(string.format('Wrote %d data records to %s',
		       countWritten, fileOutput))
   return estimates
end


print('Reading Laufer estimates')
lauferEstimates = readEstimates('laufer', 
				fileLaufer,
				'^(%d+)|(%d+)|(.*)$'
			       )


