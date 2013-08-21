-- incorporate-errors.lua 
-- Read an estimated file and completed matrix file in order to build
-- a new estimates file correcting all the estimates using the errors
-- in the completed matrix file.

-- Input files:
-- ERRORS/all-estimates-mc.csv    : apn x month error estimates
-- OBS/analysis/RESULTS/estimates-laufer.csv : apn x quarter price estimates

-- Output files:
-- ANALYSIS/RESULTS/estimates-stage2.csv
-- ANALYSIS/RESULTS/log.txt

-- CSV file schema
-- all-laufer.csv: apn, date, radius, estimatedPrice
--   where dates are midpoints in quarters
--   years = 2000, 2001, ..., 2009

-- all-estimates-mc.csv: apn, date, radius, estimatedPrice
--   where dates are mid points of each month

-- estimates-completed.csv: apn, date, radiues, stage2Price
--   where dates are mid points of each quarter

require 'affirm'
require 'assertEqual'
require 'createResultsDirectoryName'
require 'CsvUtils'
require 'IncompleteMatrix'
require 'Log'
require 'makeVerbose'
require 'parseCommandLine'
require 'printOptions'
require 'TimerCpu'

--------------------------------------------------------------------------------
-- IncorporateErrors: CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('IncorporateErrors')

function IncorporateErrors:__init()
   -- define option defaults and explanations

   self.optionDefaults = {}
   self.optionExplanations = {}
   
   local function def(option, default, explanation)
      self.optionDefaults[option] = default
      self.optionExplanations[option] = explanation
   end

   def('algo',              '', 'Name of algorithm; in {knn, kwavg, llr}')
   def('dataDir',           '../../data/','Path to data directory')
   def('obs',               '', 'Observation set')
   def('test',              0, 'Set to 1 for testing (truncate input)')
   def('write',             0, 'Whether to write the estimates')

end -- __init

--------------------------------------------------------------------------------
-- IncoporateErrors: PUBLIC METHODS
--------------------------------------------------------------------------------

function IncorporateErrors:getOptionDefaults()
   -- return table of option names and default values for each
      return self.optionDefaults
end

function IncorporateErrors:getOptionExplanations()
   -- return table of option names and explanations for each
   return self.optionExplanations
end

function IncorporateErrors:worker(options, mainProgramName)
   -- main program
   local v = makeVerbose(true, 'IncorporateErrors:worker')

   v('options', options)
   v('mainProgramName', mainProgramName)

   affirm.isTable(options, 'options')
   affirm.isString(mainProgramName, 'mainProgramName')

   self:_validateOptions(options)

   --setRandomSeeds(options.seed)

   local paths = self:_setupPaths(options, mainProgramName)

   local log = self:_startLogging(paths.dirResults)

   -- log the command line parameters
   printOptions(options, log)

   -- log paths used
   log:log(' ')
   log:log('Paths used')
   for k, v in pairs(paths) do
      log:log('%-20s = %s', k, v)
   end

   local errors = self:_readErrors(options, log, paths)
   local prices = self:_readPrices(options, log, paths)
   local stage2Estimates = self:_incorporateErrrors(errors, 
                                                    options, 
                                                    prices, 
                                                    log)
   self:_writeStage2Estimates(log, options, paths, stage2Estimates)

   printOptions(options, log)
   log:log('torch.initialSeed()', torch.initialSeed())
   
   if options.test == 1 then
      log:log('TESTING')
   end

   log:log('consider commiting the source code')
   
   log:log('\nfinished')
   log:close()
end -- worker

--------------------------------------------------------------------------------
-- IncorporateErrors: PRIVATE METHODS
--------------------------------------------------------------------------------


function IncorporateErrors:_isMidQuarter(date)
   -- return true iff date is mid quarter
   local day = string.sub(date, 7, 8)
   if day ~= '15' then
      return false
   end
   local month = string.sub(date, 5, 6)
   if month == '02' or month == '05' or month == '08' or month == '11' then
      return true
   else
      return false
   end
end -- _isMidQuarter

function  IncorporateErrors:_parseFields(line, log, hasRadius)
   -- given input line, return ok, apn, date, number
   -- where 
   --  ok = true, indicates other values are OK
   --  ok = false, indicates other values are not supplied

   local v = makeVerbose(true, 'IncorporateErrors:_parseFields')
   v('line', line)
   local hasRadius = hasRadius or false

   local apn, date, numberString
   if hasRadius then
      apn, date, numberString =  
         string.match(line, '(%d+),(%d+),%d+,([%-%d%.]+)')
   else
      apn, date, numberString = 
         string.match(line, '(%d+),(%d+),([%-%d%.]+)')
   end

   v('apn,date,number', apn, date, numberString)
   if apn == nil or 
      date == nil or 
      numberString == nil then
      log:log('not parsed: %s', line)
      return false
   end
   if string.len(apn) ~= 10 then
      log:log('apn not 10 characters: %s', apn)
      return false
   end
   if string.len(date) ~= 8 then
      log:log('date not 8 character: %s', date)
      return false
   end
   if string.sub(date, 7, 8) ~= '15' then
      log:log('date not mid month: %s', date)
      return false
   end
   local number = tonumber(numberString)
   if not number then
      log:log('not a number: %s', numberString)
      return false
   end
   return true, apn, date, number
end -- _parseFields

function IncorporateErrors:_readApnDateNumber(path, options, log)
   -- read input file
   -- return table with key==apn..date value==number containing
   -- just values at mid quarter
   -- ARGS
   -- path    : string, path to input CSV file
   --           fields in the CSV file are: apn, date, ignored, number
   -- options : table of options
   -- log     : Log instance
   -- RETURNS
   -- table   : table with 
   --           key == apn .. date (both strings)
   --           value == the number in the file 
   local v = makeVerbose(true, 'IncorporateErrors:_readApnDateNumber')
   v('path', path)
   v('options', options)
   v('log', log)

   local input = io.open(path)
   if input == nil then
      error('unable to open CSV; path = ' .. path)
   end

   local header = input:read()
   print('header', header)

   result = {}
   local countInput = 0
   local countNotMidQuarter = 0
   local countUsed = 0
   for line in input:lines('*l') do
      countInput = countInput + 1

      if options.test == 1 and
         countInput > 1000
      then
         break
      end

      local ok, apn, date, number = self:_parseFields(line, log)
      v('ok,apn,date,number', ok, apn, date, number)
      if ok then
         if self:_isMidQuarter(date) then
            result[apn..date] = number
            countUsed = countUsed + 1
            if countInput % 1000000 == 0 then
               print(
                  string.format('used: countInput %d apn %s date %s number %f',
                                countInput, apn, date, number))
            end
         else
            countNotMidQuarter = countNotMidQuarter + 1
         end
      else
         -- bad input record
         halt() -- for now, later log and count
      end
      
   end
   log:log('File contained %d data records', countInput)
   log:log(' %d were not for the mid-quarter date, hence not used', 
           countNotMidQuarter)
   log:log(' %d of these were for mid-quarter date, hence use', countUsed)
   return result
end -- _readApnDateNumber

function IncorporateErrors:_readErrors(options, log, paths)
   -- read the file with the completed error matrix
   -- return table key == apn..date value == the error
   return self:_readApnDateNumber(paths.fileErrors, options, log)
end -- _readErrors

function IncorporateErrors:_readPrices(options, log, paths)
   local hasRadius = true
   return self:_readApnDateNumber(paths.fileStage1, options, log, hasRadius)
end -- _readPrices

function IncorporateErrors:_setupPaths(options, programName)
   --  establish paths to directories and files
   -- ARGS
   -- options: table of parsed command line parameters
   -- programName : string, name of the lua executable
   -- RETURNS table of paths with these fields
   -- fileErrors : string, path to error file
   -- fileStage1 : string, path to stage 1 estimates
   -- dirResults : string, path to results directory

   local v = makeVerbose(false, 'IncorporateErrors:_setupPaths')

   v('options', options)
   v('programName', programName)
  
   affirm.isTable(options, 'options')
   affirm.isString(programName, 'programName')

   local dirObs = options.dataDir .. 'generated-v4/obs' .. options.obs .. '/'
   local dirAnalysis = dirObs .. 'analysis/'
                                                 
   local paths = {}

   -- replace .'s in program name with -'s
   paths.dirResults =
      dirAnalysis .. 
      createResultsDirectoryName(string.gsub(programName, '%.', '-'),
                                 options,
                                 self.optionDefaults) .. '/'
      
   local function radius()
      if options.algo == 'knn' and options.obs == '1A' then
         return '76'
      else
         error('unimplemented algo/obs combination')
      end
   end -- radius
   
   local function rank()
      if options.algo == 'knn' and options.obs == '1A' then
         return '1'
      else
         error('unimplemented algo/obs combination')
      end
   end -- rank

   paths.fileErrors =
      dirAnalysis ..
      'complete-matrix-lua,' ..
      'algo=' .. options.algo .. ',' ..
      'col=month,' ..
      'obs=' .. options.obs .. ',' ..
      'radius=' .. radius() .. ',' ..
      'rank=' .. rank() .. ',' ..
      'which=complete,' ..
      'write=1,' ..
      'yearFirst=1984/' ..
      'all-estimates-mc.csv'

   paths.fileStage1 =
      dirAnalysis ..
      'create-estimates-lua,' ..
      'algo=' .. options.algo .. ',' ..
      'obs=' .. options.obs .. ',' ..
      'radius=' .. radius() .. ',' ..
      'which=mc/' ..
      'estimates-mc.csv'

   v('paths', paths)
   return paths
end -- _setupPaths


function IncorporateErrors:_startLogging(dirResults)
   -- create log object and results directory; start logging
   -- ARG
   -- dirResults: string, path to directory
   -- RETURN
   -- log: instance of Log

   assert(dirResults)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      print('results directory not created', command)
      os.exit(false) -- exit with return status EXIT_FAILURE
   end
   
   -- create log file
   pathLogFile = dirResults .. 'log.txt'
   local log = Log(pathLogFile)
   log:log('log started on ' .. os.date())
   
   return log
end -- _startLogging

function IncorporateErrors:_optionError(msg)
   -- report an error in an option
   -- print all the options available

   print('AN ERROR WAS FOUND IN AN OPTION')
   print(msg)

   print('\nAvailable options, defaults, and explanations are')
   local sortedKeys = sortedKeys(options)
   for i = 1,#sortedKeys do
      local name = sortedKeys[i]
      local default = self.optionDefaults[name]
      local explanation = self.optionExplanations[name]
      print(string.format('%17s %-12s %s',
                          name, tostring(default), explanation))
   end
   error('invalid option: ' .. msg)
end -- _optionError

function IncorporateErrors:_validateOptions(options)
   -- validate options that were supplied and set default values for those not
   -- supplied
   -- validate that no extra options were supplied

   -- check for extra options
   for name in pairs(options) do
      if self.optionDefaults[name] == nil then
         self:_optionError('extra option: ' .. name)
      end
   end

   -- supply defaults for any missing option values
   for name, default in pairs(self.optionDefaults) do
      if options[name] == nil then
         options[name] = default
      end 
   end

   -- validate all the option values
   
   -- check for missing required options

   function missing(name)
      self:_optionError('missing option -' .. name)
   end

   if options.algo == ''     then missing('algo') end
   if options.dataDir == ''  then missing('dataDir') end
   if options.obs == ''      then missing('obs') end

   -- check for allowed parameter values
   if not check.isString(options.algo) or
      not options.algo == 'knn'
   then 
      self:_optionError('algo must be knn (for now)')
   end

   if not check.isString(options.dataDir) then
      self:_optionValue('dataDir must be a string')
   end

   if not check.isString(options.obs) or
      not (options.obs == '1A' or
           options.obs == '2R' or
           options.obs == '2A')
   then
      self:_optionValue('obs must be 1A, 2R, or 2A')
   end

   if not check.isInteger(options.test) or
      not (options.test == 0 or
           options.test == 1)
   then
      self:_optionValue('test must be 0 or 1')
   end

   if not check.isInteger(options.write) or
      not (options.write == 0 or
           options.write == 1)
   then
      self:_optionValue('write must be 0 or 1')
   end
end -- _validateOptions

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

local incorporateErrors = IncorporateErrors()

local options = parseCommandLine(arg,
                                 'incorporate errors into estimates',
                                 incorporateErrors:getOptionDefaults(),
                                 incorporateErrors:getOptionExplanations())

incorporateErrors:worker(options,
                         'incorporate-errors.lua')


-------------------------- OLD CODE BELOW ME

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
   if log then
      log:log('Command line parameters')
   else
      print('Command line parameters')
   end
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
end


--------------------------------------------------------------------------------
-- readCommandLine: parse and validate command line
--------------------------------------------------------------------------------

-- ARGS
-- arg    : Lua's command line arg object
-- RETURNS:
-- cmd    : object used to parse the args
-- params : table of parameters found
function readCommandLine(arg)

   cmd = torch.CmdLine()
   cmd:text('Incorporate errors into stage 1 estimates')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-algo', '', 'for now, "knn"')
   cmd:option('-dataDir', '../../data/', 'Path to data directory')
   cmd:option('-obs',                '', 'obs set, only "1A" for now')
   cmd:option('-inRank',          0, 'ID for error input file')
   cmd:option('-inTimeSgd',       0, 'seconds used in complete-matrix')

   -- parse command line
   params = cmd:parse(arg)

   -- check for missing required command line parameters

   if params.algo == '' then
      error('missing -algo parameters')
   end

   if params.obs == '' then
      error('missing -obs parameter')
   end

   function check(name, allowed)
      local value = params[name]
      if value == 0 then
         error('missing parameter -' .. name)
      end
      if not (value == math.floor(value)) then
         error(string.format('parameter %s must be an integer', name))
      end
      if value ~= allowed then
         error(string.format('parameter -%s must be %d', name, max))
      end
   end

   -- check for presence on command line and allowed values
   check('inRank', 1)  -- for now, just 1 allowed value

   if params.inTimeSgd == 0 then
      error('missing parameter -inTimeSgd')
   end

   if params.obs == nil then
      error('must supply -obs parameter')
   end

   return cmd, params
end

--------------------------------------------------------------------------------
-- setupDirectories
--------------------------------------------------------------------------------

-- determine directories
-- ARGS:
-- cmd    : CmdLine object used to parse args
-- params : table of parsed command line parameters
-- RESULTS:
-- dirInErrors     : string
-- dirInPrices     : string
-- dirResults      : string
function setupDirectories(cmd, params)
   local programName = 'incorporate-errors-lua'

   local dirObs = params.dataDir .. 'generated-v4/obs' .. params.obs .. '/'
   local dirAnalysis = dirObs .. 'analysis/'
   local dirFeatures = dirObs .. 'features/'

   local function makeInDirErrors(rank, timeSgd)
      assert(rank)
      assert(timeSgd)
      local result = 
         dirAnalysis ..
         'complete-matrix-lua,' ..
         'algo=' .. params.algo .. ',' ..
         'col=month,' ..
         'learningRate=0.1,' ..
         'learningRateDecay=0.1,' ..
         'obs=1A,' ..
         'radius=76,' ..
         'rank=' .. tostring(rank) .. ',' ..
         'timeLbfgs=600,' ..
         'timeSgd=' .. tostring(timeSgd) .. ',' ..
         'which=complete,' ..
         'write=yes,' ..
         'yearFirst=1984' ..
         '/'
      return result
   end

   local dirInErrors = makeInDirErrors(params.inRank,
                                       params.inTimeSgd)

   local dirInPrices = 
      dirAnalysis ..
      'create-estimates-lua,' ..
      'algo=' .. params.algo .. ',' ..
      'obs=' .. params.obs .. ',' ..
      'radius=76,' ..
      'which=laufer' ..
      '/'
   
   local dirResults = dirAnalysis .. cmd:string(programName,
                                                params,
                                                {}) .. '/'
   

   return dirInErrors, dirInPrices, dirResults
end  -- setupDirectories


--------------------------------------------------------------------------------
-- startLogging: create log file and results directory; start logging
--------------------------------------------------------------------------------

-- ARG
-- dirResults: string, path to directory
-- RETURN
-- log: instance of Log
function startLogging(dirResults)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      print('results directory not created', command)
      os.exit(false) -- exit with return status EXIT_FAILURE
   end
   
   -- create log file
   pathLogFile = dirResults .. 'log.txt'
   local log = Log(pathLogFile)
   log:log('log started on ' .. os.date())

   return log
end


   
--------------------------------------------------------------------------------
-- printTableHead: print first 10 records of table
--------------------------------------------------------------------------------

-- t is a table of tables
function printTableHead(name, t)
   print()
   print(name)
   local count = 0
   for k, v in pairs(t) do
      print(k, v)
      count = count + 1
      if (count > 10) then break end
   end
end
   

  
--------------------------------------------------------------------------------
-- isMidQuarter
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- readFileApnDateRadiusNumber
--------------------------------------------------------------------------------


-- return table[apn..date] = number constructed from values in CSV file
function readFileApnDateRadiusNumber(name, path, log)
   local trace = true
   log:log('reading %s file', name)
   local input = io.open(path)
   if input == nil then
      error('unable to open CSV; path = ' .. path)
   end

   local header = input:read()
   print('header', header)

   result = {}
   local countInput = 0
   local countNotMidQuarter = 0
   local countUsed = 0
   for line in input:lines('*l') do
      countInput = countInput + 1
      local ok, apn, date, number = parseFields(line, log)
      if ok then
         if isMidQuarter(date) then
            result[apn..date] = number
            countUsed = countUsed + 1
            if countInput % 1000000 == 0 then
               print(
                  string.format('used: countInput %d apn %s date %s number %f',
                                countInput, apn, date, number))
            end
         else
            countNotMidQuarter = countNotMidQuarter + 1
         end
      else
         -- bad input record
         halt() -- for now, later log and count
      end
      
   end
   log:log('File contained %d data records', countInput)
   log:log(' %d were not for the mid-quarter date, hence not used', 
           countNotMidQuarter)
   log:log(' %d of these were for mid-quarter date, hence use', countUsed)
   return result
end


--------------------------------------------------------------------------------
-- readErrors
--------------------------------------------------------------------------------

-- read the completed error matrix from a CSV file
-- create table[apn..date] = error for only mid-quarter dates
function readErrors(path, log)
   return readFileApnDateRadiusNumber('errors', path, log)
end

--------------------------------------------------------------------------------
-- readPrices
--------------------------------------------------------------------------------

-- read the price estimates from the laufer estimates file
-- create table[apn..date] = price, which will contain mid-quarter data only
function readPrices(path, log)
   return readFileApnDateRadiusNumber('prices', path, log)
end

--------------------------------------------------------------------------------
-- incorporateErrors
--------------------------------------------------------------------------------

-- merge tables errors and prices
-- return new table with updated prices table[apn..date] = updatedPrice
-- errors were computed as
--    error = actual - estimate
-- We want to determine hat(actual), so we compute
--    actual = error + estimate
function incorporateErrors(errors, prices, log)
   log:log('incorporating errors into price estimates')
   local stage2 = {}
   local countErrorFound = 0
   local countErrorNotFound = 0
   local countPrices = 0
   for apnDate, estimate in pairs(prices) do
      countPrices = countPrices + 1
      local error = errors[apnDate]
      if error then
         countErrorFound = countErrorFound + 1
         stage2[apnDate] = error + estimate
         if countErrorFound <= 10 then
            log:log('apnDate %s estimate %f error %f stage2Estimate %f',
                    apnDate, estimate, error, stage2[apnDate])
         end
      else
         countErrorNotFound = countErrorNotFound + 1
      end
   end
   log:log('There were %d prices', countPrices)
   log:log('Of which')
   log:log('  %d had corresponding errors', countErrorFound)
   log:log('  %d did not have corresponding errors', countErrorNotFound)
   return stage2
         
end

--------------------------------------------------------------------------------
-- writeStage2Estimates
--------------------------------------------------------------------------------

-- write the stage2 estimates to a CSV file
function writeStage2Estimates(estimates, path, radius, log)
   local trace = false
   log:log('Writing stage 2 estimates to %s', path)
   local output = io.open(path, 'w')
   if output == nil then
      print('unable to open output CSV; path = ' .. path)
   end

   -- write header
   output:write('apn,date,radius,estimate\n')
   
   -- write each data record
   local countWritten = 0
   for apnDate, estimate in pairs(estimates) do
      local apn = string.sub(apnDate, 1, 10)
      local date = string.sub(apnDate, 11, 18)
      assert(apn, apn)
      assert(date, date)
      assert(string.len(apn) == 10)
      assert(string.len(date) == 8)
      local line =
         string.format('%s,%s,%d,%f\n',
                       apn, date, radius, estimate)
         if trace then
            print('output line', line)
         end
         local ok, error = output:write(line)
         if ok == nil then
            print('error in writing line:', line)
            print('error message:', error)
            exit(false)
         end
         countWritten = countWritten + 1
         if countWritten % 100000 == 0 then
            log:log('wrote data record %d: %s', countWritten, line)
         end
   end
   log:log('Wrote %d data records', countWritten)
   output:close()
end -- writeStage2Estimates
      
   

--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

local cmd, params = readCommandLine(arg)
local dirInErrors, dirInPrices, dirResults =
   setupDirectories(cmd, params)

-- start log and log command line parameters
local log = startLogging(dirResults)
printParams(params, log)

-- set paths to input and output files and log them
print('dirInErrors', dirInErrors)
local pathInErrors = dirInErrors .. 'all-estimates-mc.csv'
local pathInPrices = dirInPrices .. 'estimates-laufer.csv'
local pathOutEstimates = dirResults .. 'estimates-stage2.csv'

function logPath(name, value)
   log:log('%-20s = %s', name, value)
end

log:log('\nPath to input and output files')
logPath('pathInErrors', pathInErrors)
logPath('pathInPrices', pathInPrices)
logPath('pathOutEstimates', pathOutEstimates)

local skipReadErrors = false
if not skipReadErrors then
   errors = readErrors(pathInErrors, log)
   printTableHead('errors', errors)
else
   log:log('skipped reading errors')
end

prices = readPrices(pathInPrices, log)
printTableHead('prices', prices)

stage2Estimates = incorporateErrors(errors, prices, log)
printTableHead('stage2Estimates', stage2Estimates)

local radius = 76
writeStage2Estimates(stage2Estimates, pathOutEstimates, radius, log)


printParams(params, log)

log:log('\nfinished')
log:close()







