-- hp-search.lua
-- search for hyperpameters

-- TODO: fix comments below
-- input files:
-- FEATURES/apns.csv
-- FEATURES/dates.csv
-- FEATURES/prices.csv
-- DATA/laufer-2012-03-hpi-values/hipvalues.txt
-- DATA/generated-v4/obsOBS/analysis/create-estimates-lau...-which=laufer/estimates-laufer.csv

require 'CsvUtils'
require 'Kwavg'
require 'Log'
require 'printParams'
require 'Set'
require 'TimerCpu'

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
-- set global variable DEBUGGING
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
end



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
   cmd:text("Search for hyperparameters")
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-algo',     '','Name of algorithm ("knn")')
   cmd:option('-by',      -1, 'Step value for hyperpameter')
   cmd:option('-dataDir', '../../data/','Path to data directory')
   cmd:option('-debug',   0, 'Set to 1 to debug')
   cmd:option('-from',    -1, 'Starting value of hyperparameter')
   cmd:option('-obs',     '', 'Observation set')
   cmd:option('-to',      -1, 'Ending value of hyperparameter')

   -- parse command line
   params = cmd:parse(arg)

   printParams(params)


   -- check for missing required command line parameters
   local function missing(name)
      error('missing parameter -' .. name)
   end

   if params.algo == ''     then missing('algo') end
   if params.by == -1      then missing('by') end
   if params.dataDir == '' then missing('dataDir') end
   if params.from == -1    then missing('from') end
   if params.obs == ''     then missing('obs') end
   if params.to == -1      then missing('to') end

   -- check for allowed parameter values
   local function inSet(value, set, name)
      if not set:hasElement(value) then
         print('value set\n')
         set:print()
         error('%s not in value set')
      end
   end

   local function nonnegative(value, name)
      if not (value >= 0) then
         error(string.format('%s must be nonnegative', name))
      end
   end

   local function positive(value, name)
      if not (value > 0) then
         error(string.format('%s must be positive', name))
      end
   end
   
   inSet(params.algo, Set('kwavg'), 'algo')
   positive(params.by, 'by')
   inSet(params.debug, Set(0, 1), 'debug')
   nonnegative(params.from, 'from')
   inSet(params.obs, Set('1A'), 'obs')
   positive(params.to, 'to')

   -- check for relationships among values
   if not (params.from <= params.to) then
      error('-from must not exceed -to')
   end

   -- set global variable for ease of adding debugging code
   if params.debug == 1 then
      DEBUGGING = true
   else
      DEBUGGING = false
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
      dirAnalysis .. cmd:string('hp-search-lua',
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
-- setupInputPaths
--------------------------------------------------------------------------------

-- RETURNS
-- pathDates    : string, path to dates file
-- pathFeatures : string, path to features file
-- pathPrices   : string, path to prices file
function setupInputPaths(dirFeatures, log, params)
   local pathDates = dirFeatures .. 'date.csv'
   local pathFeatures = dirFeatures .. 'features.csv'
   local pathPrices = dirFeatures .. 'SALE-AMOUNT-log.csv'

   return pathDates, pathFeatures, pathPrices
end

--------------------------------------------------------------------------------
-- isNan
--------------------------------------------------------------------------------

-- return true if the argument is NaN
-- otherwise return false
function isNan(x)
   assert(x)
   return x ~= x
end

--------------------------------------------------------------------------------
-- assertIsNotNan
--------------------------------------------------------------------------------

-- return if value is not NaN
-- otherwise raise error and stop
function assertIsNotNan(value, name)
   assert(value)
   assert(name)
   assert(not isNan(value), string.format('%s is NaN; value = %q',
                                          name, value))
end


--------------------------------------------------------------------------------
-- printHeadSeq: print first few records of sequence
--------------------------------------------------------------------------------

function printHeadSequence(name, s)
   print('sequence', name)
   for i = 1, 10 do
      print(name, i, s[i])
   end
   if pause then continue() end
end --printHeadSequence

--------------------------------------------------------------------------------
-- printHeadTable: print first few records of table
--------------------------------------------------------------------------------

function printHeadTable(name, t)
   print('table', name)
   local count = 0
   for k, v in pairs(t) do
      print(name, k, v)
      count = count + 1
      if count == 10 then break end
   end
end --printHeadTable

--------------------------------------------------------------------------------
-- printHeadTensor1D
--------------------------------------------------------------------------------

function printHeadTensor1D(name, t)
   assert(name)
   assert(t)

   print('Tensor', name)
   for i = 1, 10 do
      print(i, t[i])
   end
end --printHeadTensor1D

--------------------------------------------------------------------------------
-- printHeadTensor2D
--------------------------------------------------------------------------------

function printHeadTensor2D(name, t)
   assert(name)
   assert(t)

   print('Tensor', name)
   for i = 1, 2 do
      print('row', i, t[i])
   end
end --printHeadTensor2D

--------------------------------------------------------------------------------
-- in200x
--------------------------------------------------------------------------------

-- return true iff date is in 2000, 2001, ..., 2009
function in200x(date)
   return string.sub(date, 1, 3) == '200'
end

do
   -- unittest
   assert(in200x('2000xxxxxx'))
   assert(in200x('20010515'))
   assert(in200x('2002'))
   assert(in200x('2003'))
   assert(in200x('20040815'))
   assert(in200x('2005'))
   assert(in200x('2006'))
   assert(in200x('2007'))
   assert(in200x('2008'))
   assert(in200x('2009'))
   assert(not in200x('1997'))
end -- unittest of in200x



--------------------------------------------------------------------------------
-- readDates
--------------------------------------------------------------------------------

-- return sequence of strings, each a date YYYYMMDD
-- check number of entries
function readDates(path, log)
   assert(path)
   assert(log)

   local result, header = CsvUtils.read1Number(path)
   
   log:log('Read %d dates records', #result)

   return result
end -- readDates

--------------------------------------------------------------------------------
-- readFeatures
--------------------------------------------------------------------------------

-- return 2D Tensor containing all the features
-- check number of observations and number of dimensions
function readFeatures(path, log)
   assert(path)
   assert(log)

   local hasHeader = true
   local result, header = CsvUtils.readNumbers(path, hasHeader, '2D Tensor')

   log:log('Read %d x %d features matrix', result:size(1), result:size(2))

   return result
end -- readFeatures

--------------------------------------------------------------------------------
-- readPrices
--------------------------------------------------------------------------------

-- return 1D Tensor of prices
function readPrices(path, log)
   assert(path)
   assert(log)

   local hasHeader = true
   local seq, header = CsvUtils.read1Number(path)

   log:log('Read %d prices', #seq)

   return torch.Tensor(seq)
end -- readPrices


--------------------------------------------------------------------------------
-- apnInTable
--------------------------------------------------------------------------------

-- return true if apn is a key of the table
-- otherwise return false
function apnInTable(apn, table)
   for apnDate, price in pairs(table) do
      local tableApn, tableDate = splitApnDate(apnDate)
      if apn == tableApn then return true end
   end
   return false
end -- apnInTable

--------------------------------------------------------------------------------
-- Tabulator
--------------------------------------------------------------------------------

do
   local Tabulator = torch.class('Tabulator')

   function Tabulator:__init()
      self.seen = 0
      self.withinTolerance = 0
      self.sumSquaredErrors = 0
      self.tolerance = 0.10       -- for within calculation
   end -- method __init

   function Tabulator:tabulate(actualLog, estimateLog)
      local trace = false
      assert(actualLog)
      assert(estimateLog)
      assertIsNotNan(actualLog, 'actualLog')
      assertIsNotNan(estimateLog, 'estimateLog')

      self.seen = self.seen + 1

      -- intermediate values for RMSE
      local errorLog = actualLog - estimateLog
      self.sumSquaredErrors = self.sumSquaredErrors + errorLog * errorLog
      assertIsNotNan(errorLog, 'errorLog')
      assertIsNotNan(self.sumSquaredErrors, 'self.sumSquaredErrors')
      if trace then
         print('Tabulator:tabulate')
         print(' actualLog', actualLog)
         print(' estimateLog', estimateLog)
         print(' errorLog', errorLog)
         print(' self.sumSquaredErrors', self.sumSquaredErrors)
      end
      
      -- intermediate values for fraction within tolerance
      local actual = math.exp(actualLog)
      local estimate = math.exp(estimateLog)
      local error = actual - estimate
      if math.abs(error / actual) < self.tolerance then
         self.withinTolerance = self.withinTolerance + 1
      end
   end -- method tabulate

   -- return RMSE, fraction within 10 percent
   function Tabulator:measures(nObservations)
      assert(nObservations)
      local trace = true
      local rmse = math.sqrt(self.sumSquaredErrors / self.seen)
      assertIsNotNan(rmse, 'rmse')
      local within10 = self.withinTolerance / self.seen
      local coverage = self.seen / nObservations
      if trace then
         print('Tabulator:measures')
         print(' self.sumSquaredErrors', self.sumSquaredErrors)
         print(' self.withinTolerance', self.withinTolerance)
         print(' self.seen', self.seen)
         print(' nObservations', nObservations)
         print(' rmse', rmse)
         print(' within10', within10)
         print(' coverage', coverage)
      end
      return rmse, within10, coverage
   end -- method measures
end

--------------------------------------------------------------------------------
-- measurePerformanceKwavg
--------------------------------------------------------------------------------

-- measure performance of Kwavg on the test transactions in 2000, ..., 2009
-- RETURNS
-- rmse     : number, measured in log domain
-- within   : number, fraction of estimates within 10 percent of actuals
--            not in log domain
-- coverage : number, fraction of test transactions that could be estimated
-- TIMING:
--   time to determine accuracy of one lambda value is 0.1 CPU seconds
--   there are about 70,000 test transactions
--   hence total CPU time = 70000 * 0.1 sec = 7000 sec = 116 minutes = 2 hours
-- DEBUGGING global variable:
--   if true, only create 100 estimates
function measurePerformanceKwavg(lambda, dates, features, prices, log)
   local trace = false
   assert(lambda)
   assert(dates)
   assert(features)
   assert(prices)
   assert(log)

   -- allow -from 0 -to 10 -by 1 on command line
   if lambda == 0 then
      lambda = 1e-6 -- some small value 
   end

   log:log('Starting to measure performance of Kwavg with lambda = %f', lambda)
   local kwavg = Kwavg('epanechnikov quadratic')
   local useQueryPoint = false
   local errorIfZeroSumWeights = true
   local tabulator = Tabulator()
   local countAttempted = 0
   local countAttemptSucceeded = 0
   local countAttemptFailed = 0
   local countSkipped = 0
   local reportFrequency = 10000
   local timer = TimerCpu()
   for obsIndex = 1, #dates do
      if in200x(dates[obsIndex]) then
         countAttempted = countAttempted + 1
         if countAttempted % reportFrequency == 0 then
            print(
               string.format(
                  'detemined %d of %d accuracy measures ' .. 
                  'in %f CPU seconds/measure',
                  countAttempted, 
                  #dates,
                  timer:cumSeconds() / countAttempted))
         end

         local ok, estimate = kwavg:smooth(features, 
                                           prices, 
                                           obsIndex, 
                                           lambda, 
                                           useQueryPoint)

         if trace then
            print('measurePerformanceKwavg ok, estimate', ok, estimate)
         end
         
         if ok then
            countAttemptSucceeded = countAttemptSucceeded + 1
            tabulator:tabulate(prices[obsIndex], estimate)
         else
            countAttemptFailed = countAttemptFailed + 1
            if trace then
               print(string.format('failed to estimate: obsIndex %d reason %s',
                                   obsIndex, estimate))
            end
         end

         -- by pass bug in Torch
         collectgarbage('collect')

         if DEBUGGING and countAttempted > 99 then
            break
         end

      else
         countSkipped = countSkipped + 1
      end
   end

   log:log('Examine %d observations', #dates)
   log:log(' Of which attempted estimates on %d of them', countAttempted)
   log:log(' Of which, skipped %d, since not in 2000, 2001, ..., 2009',
           countSkipped)
   log:log(' ')
   log:log('Of the %d attempted estimates', countAttempted)
   log:log(' Made an estimate on %d of them', countAttemptSucceeded)
   log:log(' Failed to make an estimate on %d of them', countAttemptFailed)
   assert(countAttempted == countAttemptSucceeded + countAttemptFailed)

   local totalCpu = timer:cumSeconds()
   log:log('Total CPU used: %f seconds', totalCpu)
   log:log('CPU seconds per estimate = %f', totalCpu / countAttemptSucceeded)

   return tabulator:measures(countAttempted)
end -- measurePerformanceKwavg

--------------------------------------------------------------------------------
-- measurePerformance
--------------------------------------------------------------------------------

-- measure performance of the algo on the test transactions in 2000, ..., 2009
-- leave out the query transaction
-- RETURNS
-- rmse   : number, measured in log domain
-- within : number, fraction of estimates within 10 percent of actuals
--          not in log domain
-- coverage : number, fraction of test transactions that could be estimated
function measurePerformance(hp, dates, features, prices, algo, log)
   assert(hp)
   assert(dates)
   assert(features)
   assert(prices)
   assert(algo)
   assert(log)

   if algo == 'kwavg' then
      return measurePerformanceKwavg(hp, dates, features, prices, log)
   else
      error('invalid algo; algo = ' .. algo)
   end
end -- measurePerformance


--------------------------------------------------------------------------------
-- checkFeatures
--------------------------------------------------------------------------------

-- determine if all the features are the same
function checkFeatures(features)
   assert(features)
   assert(torch.typename(features) == 'torch.DoubleTensor',
          torch.typename(features))
   local baseIndex = 3
   local nObservations = features:size(1)
   local nDimensions = features:size(2)
   local allSame = true
   local differentObservations = Set()
   for obsIndex = baseIndex + 1, nObservations do
      for dimIndex = 1, nDimensions do
         local baseValue = features[baseIndex][dimIndex] 
         local comparisonValue = features[obsIndex][dimIndex] 
         if baseValue ~= comparisonValue then
            print(
               string.format('found diff in obs %d dim %d: ' .. 
                             ' base = %f comparison = %f',
                             obsIndex, dimIndex, baseValue, comparisonValue))
            differentObservations:add(obsIndex)
         end
      end
      if differentObservations:nElements() >= 5 then
         print('at least these observation are different from obsIndex',
               baseIndex)
         differentObservations:print()
         return true
      end
   end
end -- checkFeatures
            
--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------

local cmd, params = readCommandLine(arg)
local dirAnalysis, dirFeatures, dirObs, dirResults =
   setupDirectories(cmd, params)
local log = startLogging(dirResults)

printParams(params, log)

-- log the directories
local function logDir(name, value) do log:log(' %11s %s', name, value) end end
log:log(' ')
log:log('directories used')
logDir('dirAnalysis', dirAnalysis)
logDir('dirFeatures', dirFeatures)
logDir('dirObs', dirObs)
logDir('dirResults', dirResults)

-- setup and log paths to the two input files
local pathDates, pathFeatures, pathPrices =
   setupInputPaths(dirFeatures, log, params)
local function logPath(name, value) log:log(' %12s %s', name, value) end
log:log(' ')
log:log('Paths to files read')
logPath('pathDates', pathDates)
logPath('pathFeatures', pathFeatures)
logPath('pathPrices', pathPrices)

-- read input files and print head of each
local dates = readDates(pathDates, log)
printHeadTable('dates', dates)

local features = readFeatures(pathFeatures, log)
printHeadTensor2D('features', features)
if DEBUGGING then
   checkFeatures(features)
end

local prices = readPrices(pathPrices, log)
printHeadTensor1D('prices', prices)

-- check sizes and dimensions
if params.obs == '1A' then
   local nObservations = 217376
   local nDimensions = 55
   assert(#dates == nObservations)
   assert(features:size(1) == nObservations)
   assert(features:size(2) == nDimensions)
   assert(prices:size(1) == nObservations)
   assert(features:nDimension() == 2)
   assert(prices:nDimension() == 1)
else
   error('logic; obs = ' .. params.obs)
end

-- create a bunch of estimates and log their accuracy
local timer = TimerCpu()
for hp = params.from, params.to, params.by do
   local loss, fractionWithin10, coverage = 
      measurePerformance(hp, 
                         dates, 
                         features, 
                         prices,
                         params.algo,
                         log)
   assert(loss)
   assert(fractionWithin10)
   assert(coverage)
   log:log('hp %f', hp)
   log:log('  rmse %f',loss)
   log:log('  fraction within 10 percent %f',fractionWithin10)
   log:log('  coverage %f', coverage)
   --log:log('  in %f CPU secs', timer:cumSeconds())

end


printParams(params, log)
if DEBUGGING then log:log('DEBUGGING') end

log:log(' ')
log:log('finished')

log:close()



