-- create-features.lua
-- create a features.csv file in the FEATURES directory

require 'CsvUtils'
require 'Log'

--------------------------------------------------------------------------------
-- continue: print msg and wait for keystroke
--------------------------------------------------------------------------------

function continue(...)
   print(...)
   print('hit ENTER to continue')
   io.read()
end

--------------------------------------------------------------------------------
-- printParams
--------------------------------------------------------------------------------

-- print or log parameters
function printParams(params, log)
   print('Command line parameters')
   keys = {}
   for k in pairs(params) do
      keys[#keys + 1] = k
   end
   table.sort(keys)
   for i = 1, #keys do
      local key = keys[i]
      local value = params[key]
      local line = string.format('%17s %s', key, value)
      if log then
         log:log(line)
      else
         print(line)
      end
   end
end -- printParams



--------------------------------------------------------------------------------
-- read command line
--------------------------------------------------------------------------------

-- validate command line parameters and print them on stdout
-- ARG:
-- arg : torch's command line
-- RETURNS
-- cmd object
-- table of parameters
function readCommandLine(args)
   readLaufer = true
   readRoy = true

   local cmd = torch.CmdLine()
   cmd:text("Create consolidated features.csv file")
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-dataDir','../../data/','Path to data directory')
   cmd:option('-obs','', 'Observation set, for now 2R')

   -- parse command line
   params = cmd:parse(arg)

   printParams(params)


   -- check for missing required command line parameters
   function missing(name)
      error('missing parameter -' .. name)
   end

   if params.obs == '' then missing('obs') end

   -- check for allowed parameter values
   if params.obs ~= "2R" then
      error('-obs must be 2R for now')
   end

   return cmd, params
end
   

--------------------------------------------------------------------------------
-- setupDirectories
--------------------------------------------------------------------------------

-- ARGS
-- cmd : CmdLine object
-- params: table of parsed command line parameters
-- RESULTS
-- dirAnalysis
-- dirFeatures
-- dirObs
-- dirResults
function setupDirectories(cmd, params)
   local dirObs = params.dataDir .. 'generated-v4/obs' .. params.obs .. '/'
   local dirAnalysis = dirObs .. 'analysis/'
   local dirFeatures = dirObs .. 'features/'
   local dirResults =
      dirAnalysis .. cmd:string('compare-estimates-lua',
                                params,
                                {}) .. '/'
   return dirAnalysis, dirFeatures, dirObs, dirResults
end



--------------------------------------------------------------------------------
-- startLogging
--------------------------------------------------------------------------------

-- create log file and results director and start logging
-- ARG
-- dirResults
-- RETURN
-- log : instance of Log
function startLogging(dirResults)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      error('results directory not created', command)
   end
   
   -- create log file
   local log = Log(dirResults .. 'log.txt', params)
   log:log('log started on ' .. os.date())
   return log
end

--------------------------------------------------------------------------------
-- createFeatures2R
--------------------------------------------------------------------------------

-- write file features.csv for observations set 2R
function createFeatures2R(dirFeatures, log)
   local outPath = dirFeatures .. 'features.csv'
   local outFile, msg = io.open(outPath, 'w')
   if outFile == nil then
      error('failed to open features file, msg = ' .. msg)
   end

   log:log('Writing output file %s', outPath)


   -- define the fields
   names = {}

   local function field(name)
      names[#names + 1] = name
   end

   field('ACRES-log-std')
   field('BEDROOMS-std')
   field('census-avg-commute-std')
   field('census-income-log-std')
   field('census-ownership-std')
   field('day-std')
   field('IMPROVEMENT-VALUE-CALCULATED-log-std')
   field('LAND-VALUE-CALCULATED-log-std')
   field('latitude-std')
   field('LIVING-SQUARE-FEET-log-std')
   field('LOCATION-INFLUENCE-CODE')
   field('longitude-std')
   field('PARKING-SPACES-std')
   field('POOL-FLAG-is-0')
   field('POOL-FLAG-is-1')
   field('TRANSACTION-TYPE-CODE-is-1')
   field('TRANSACTION-TYPE-CODE-is-3')
   field('YEAR-BUILT-std')
  
   -- create and write header
   local header = ''
   for i = 1, #names do
      if i > 1 then
         header = header .. ','
      end
      header = header .. names[i]
   end
   log:log('header = %s ', header)
   outFile:write(header .. '\n')

   -- build up 2D tensor of values
   nRows = 1513786
   nCols = #names
   local values = torch.Tensor(nRows, nCols)

   for i = 1, #names do
      local fileName = names[i] .. '.csv'
      log:log('reading input file %s.csv', fileName)
      data = CsvUtils.read1Number(dirFeatures .. fileName)
      if #data ~= nRows then
         log:log('file %s has %d data rows, not expected %d',
                 fileName, #data, nRows)
         error('wrong number of rows')
      else
         for j = 1, #data do
            values[j][i] = data[j]
         end
      end
   end

   -- write the values to features.csv
   local countWritten = 0
   for rowIndex = 1, nRows do
      local line = ''
      for colIndex = 1, #names do
         if colIndex > 1 then
            line = line .. ','
         end
         line = line .. (string.format('%s', values[rowIndex][colIndex]))
      end
      outFile:write(line .. '\n')
      countWritten = countWritten + 1
      if countWritten < 11 then 
         log:log('wrote %s', line)
      end
   end
      
   log:log('wrote %d data records to features.csv', countWritten)

   outFile:close()
end
   
--------------------------------------------------------------------------------
-- createFeatures
--------------------------------------------------------------------------------

-- read all the features files and write features.csv
function createFeatures(obs, dirFeatures, log)
   if obs == '2R' then
      createFeatures2R(dirFeatures, log)
   else
      error('bad obs = ', obs)
   end
end -- createFeatures
   


--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------

local cmd, params = readCommandLine(arg)
local dirAnalysis, dirFeatures, dirObs, dirResults =
   setupDirectories(cmd, params)
local log = startLogging(dirResults)

printParams(params, log)

-- log the directories
log:log(' ')
log:log('directories used')
local function logDir(name, value) do log:log(' %11s %s', name, value) end end
logDir('dirAnalysis', dirAnalysis)
logDir('dirFeatures', dirFeatures)
logDir('dirObs', dirObs)
logDir('dirResults', dirResults)

createFeatures(params.obs, dirFeatures, log)

printParams(params, log)

log:log(' ')
log:log('finished')

log:close()




