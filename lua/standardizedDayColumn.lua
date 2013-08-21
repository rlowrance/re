-- standardizedDayColumn.lua

require 'affirm'
require 'makeVerbose'

function standardizedDayColumn(dataDir, obs)
   -- return an integer, the column number in features containing the 
   -- standardized day

   local v = makeVerbose(false, 'standardizedDayColumn')
   affirm.isString(dataDir, 'dataDir')
   affirm.isString(obs, 'obs')
   
   assert(obs == '1A' or obs == '2R')
   
   local filename = 'obs' .. obs .. '-all-features.csv'
   local dir = dataDir .. 'v5/inputs/'
   local path = dir .. filename
   
   local file, err = io.open(path, 'r')
   if file == nil then
      error('did not open file; err = ' .. err)
   end


   local header = file:read()
   v('header', header)
   file:close()

   columnNumber = 0
   for field in string.gmatch(header,'([^,]+),') do
      v('field', field)
      columnNumber = columnNumber + 1
      if field == 'day-std' then 
         return columnNumber 
      end
   end
   error('did not column name sought; header = ' .. header)
end -- standardizedDayColumn