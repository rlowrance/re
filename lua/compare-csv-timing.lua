-- compare-csv-timing.lua
-- compare timing to read a large CSV file with the Csv class and directly

-- results
-- reading with Csv class takes 146 seconds
-- reading directly takes 50 seconds

--[[ stdout:
time csv    {[sys]  = 0.392024
 [user] = 144.409025
 [real] = 146.70252585411}
time fast    {[sys]  = 0.192012
 [user] = 48.979061
 [real] = 49.82840681076}
--]]

-- Note: the test file is too large to be read via dofile, if it is 
-- converted first to a sequence of lua statemants, as in
 -- t{"apn","date","estimate"}
 -- t{2004001005,20000215,123.45}
 -- ...

require 'csv'

-- the test file is Laufer's HPI-based estimates

inFilePath = '../../data/laufer-2012-03-hpi-values/hpivalues.txt'
print('inFilePath', inFilePath)

-- define functions to read the infile each way

function readEstimatesCsv(inFilePath, separator)
   local csv = Csv(inFilePath, 'r', separator)
   local header = csv:read()
   while true do
      local dataStrings = csv:read()
      if not dataStrings then break end
      -- do something with the values
   end
   csv:close()
   return result
end

function readEstimatesFast(inFilePath, pattern)
   local file = io.open(inFilePath, 'r')
   local header = file:read('*l')
   for line in file:lines('*l') do
      local apn, date, estimate = string.match(line, pattern)
      -- do something with the values
   end
   file:close()
   return result
end

-- compare timing of two approaches

do
   local timer = torch.Timer()
   readEstimatesCsv(inFilePath, '|')
   print('time csv', timer:time())
end

do
   local timer = torch.Timer()
   readEstimatesFast(inFilePath, '^(%d+)|(%d+)|(%d+%.%d*)')
   print('time fast', timer:time())
end

print('Finished')