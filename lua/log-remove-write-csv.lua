-- log-remove-write-csv.lua
-- usage:
--    log-remove-write-csv.lua inFilePath outFilePath
-- NOTE: You cannot write a filter in torch, because torch writes
-- to stdout!
-- a filter to remove all but the first writeCsv lines from a log file

local inFilePath = arg[1]
inFile = io.open(inFilePath, 'r')

local outFilePath = arg[2]
outFile = io.open(outFilePath, 'w')

for line in inFile:lines('*l') do
   --print('in', line)
   if not string.match(line, '^writeCsv*') then
      --print('out', line)
      outFile:write(line)
      outFile:write('\n')
   end
end

inFile:close()
outFile:close()

         
      