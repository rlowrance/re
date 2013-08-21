-- convert-csv-to-lua.lua
-- convert a csv file to a lua program file

-- NOTE: The file hpivalues.txt (from Laufer)
-- has an extra carriage return (^M in emacs) at the end of each record
-- These values are carried forward in the copy operation here

require 'Csv'

-- non-commandline parametes
functionName = 'd'  -- for data

cmd= torch.CmdLine()
cmd:text('Convert csv file to lau program file')
cmd:text()
cmd:option('-file','','required filenamebase path that is the input')
cmd:option('-separator','|','optional csv separator character')
cmd:option('-suffix', 'csv', 'optional suffix for file name')
cmd:option('-quote','"','optional csv quote character')
cmd:text()

params = cmd:parse(arg)

params.rundir = cmd:string('convert-csv-to-lua', params, {})

-- create log file
os.execute('mkdir -p ' .. params.rundir)
cmd:log(params.rundir .. '/log.txt', params)

-- check parameters
if not params.file then
   error('missing required parameter file')
end


out = io.open(params.file .. '.lua', 'w')
csv = Csv(params.file .. '.' .. params.suffix, 
	  'r', 
	  params.separator, 
	  params.quote)
header = csv:read()
out:write(functionName)
out:write('{')
for i = 1,#header do
   out:write('"')
   out:write(header[i])
   out:write('"')
   out:write(',')
end
out:write('}')
out:write('\n')


while true do
   local dataStrings = csv:read()
   if not dataStrings then break end
   out:write(functionName)
   out:write('{')
   for i = 1,#dataStrings do
      out:write(dataStrings[i])
      out:write(',')
   end
   out:write('}')
   out:write('\n')
end

csv:close()
out:close()

print('Finished')

   

