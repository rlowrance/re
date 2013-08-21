-- complete-matrix.lua
-- read estimates of transactions, determine sparse error matrix, and
-- complete matrix for all time periods and APNs

-- Input files:
-- FEATURES/apns.csv
-- FEATURES/dates.csv
-- FEATURES/SALE-AMOUNT-log.csv
-- ANALYSIS/create-estimates-lua-...-which=mc/estimates-mc.csv

-- Output files:
-- ANALYSIS/RESULTS/all-estimates-mc.csv
-- ANALYSIS/RESULTS/log.txt


require 'assertEqual'
require 'checkGradient'
require 'CsvUtils'
require 'IncompleteMatrix'
require 'Log'
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
-- readCommandLine: parse and validate command line
--------------------------------------------------------------------------------

-- ARGS
-- arg  Lua's command line arg object
-- RETURN
-- cmd object used to parse the args
-- options: table of parameters found
function readCommandLine(arg)

   cmd = torch.CmdLine()
   cmd:text('Complete matrix of errors for given rank' ..
            ' for one algorithm, obs set, and radius')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-algo',      '',    'Name of algorithm ("knn")')
   --cmd:option('-cache',   '','file name for ending/starting value of weights')
   cmd:option('-col',       '',    'Columns ("month", "quarter")')
   cmd:option('-dataDir',   '../../data/','Path to data directory')
   cmd:option('-justLbfgs', 0, 'for which=time, run only L-BFGS')
   cmd:option('-lambda',    0.001, 'regularizer constant')
   cmd:option('-learningRate', 0, 'Learning rate for which=complete')
   cmd:option('-learningRateDecay', 0, 'Learning rate decay for which=complete')
   cmd:option('-obs',       '',    'Observation set')
   cmd:option('-radius',    0,     'Value of radius parameter')
   cmd:option('-rank',      0,     'Elements in each latent variable')
   cmd:option('-seed',     27,     'random number seeds for torch and lua')
   cmd:option('-test',      0,     'set to 1 for testing (TODO: truncate input)')
   cmd:option('-time1',     0,     'CPU seconds for phase 1')
   cmd:option('-time2',     0,     'CPU seconds for phase 2')
   cmd:option('-timeLbfgs', 
              0,     
              'Max CPU seconds for L-BFGS for which=complete')
   cmd:option('-timeSgd',
              0,
              'Max CPU seconds for SGD for which=complete')
   cmd:option('-which',     '',    'oneof{"checkGradient","complete","time"')
   cmd:option('-write',     'no',  'whether to write the completed matrix')
   cmd:option('-yearFirst', 0,     'first year to consider')     
   cmd:text()

   -- parse command line
   options = cmd:parse(arg)

   -- check for missing required command line parameters

   function missing(name)
      error('missing parameter -' .. name)
   end

   if options.algo == ''     then missing('algo') end
   if options.col == ''      then missing('col') end
   if options.dataDir == ''  then missing('dataDir') end
   if options.features == '' then missing('features') end
   if options.obs == ''      then missing('obs') end
   if options.radius == 0    then missing('radius') end
   if options.which == ''    then missing('which') end
   if options.yearFirst == 0 then missing('yearFirst') end

   -- check for allowed parameter values

   if not (options.col == 'month' or options.col == 'quarter') then
      error('-col must be "month" or "quarter"')
   end

   if options.lambda < 0 then error('-lambda must not be negative') end

   if options.rank <= 0 then error('-rank must be postive') end
   if options.rank ~= math.floor(options.rank) then 
      error('-rank must be an integer') 
   end

   if not (options.test == 0 or options.test == 1) then
      error('-test must be 0 or 1')
   end

   if not (options.which == 'checkGradient' or 
           options.which == 'complete' or 
           options.which == 'time') then
      error('-which must be "checkGradient" or "complete" or "time"')
   end

   if not (1984 <= options.yearFirst and options.yearFirst <= 2009) then
      error('-yearFirst must be in [1984,2009]')
   end

   if options.which == 'complete' then
      if options.radius == 0 then missing('radius') end
      if options.radius < 1 then error('radius must be positive') end

      if options.learningRate == 0 then missing('learningRate') end
      if options.learningRate <= 0 then 
         missing('learningRate must be postiive') 
      end
         
      if options.learningRateDecay == 0 then missing('learningRateDecay') end
      if options.learningRateDecay < 0 then
         error('learningRateDecay must be non-negative')
      end

      if options.timeLbfgs == 0 then missing('timeLbfgs') end
      if options.timeLbfgs <= 0 then error('timeLbgs must be postive') end

      if options.timeSgd == 0 then missing('timeSgd') end
      if options.timeSgd <= 0 then error('timeSgd must be positive') end
   end

   if options.which == 'time' then
      if options.time1 == 0 then missing('time1') end
      -- time2 == 0 is OK 
   end

   if options.write ~= 'no' and 
      options.write ~= 'yes' then
      error('-write must be oneOf{"no", "yes"}')
   end

   return cmd, options
end

--------------------------------------------------------------------------------
-- setupDirectories: establish paths to directories and files
--------------------------------------------------------------------------------

-- ARGS
-- cmd: CmdLine object used to parse args
-- options: table of parsed command line parameters
-- RETURNS table of directories with these fields
-- .analysis
-- .incompleteEstimates: string, path to incomplete matrix estimates
-- .features
-- .results
function setupDirectories(cmd, options)
   local programName = 'complete-matrix-lua'
   local dirObs = options.dataDir .. 'generated-v4/obs' .. options.obs .. '/'
   local dirAnalysis = dirObs .. 'analysis/'
   local dirFeatures = dirObs .. 'features/'
   
   -- the name of the directory with Roy's estimates depends on the algorithm
   local dirIncompleteEstimates
   if options.algo == 'knn' or options.algo == 'kwavg' then
      dirIncompleteEstimates = 
         dirAnalysis .. 
         string.format(
           'create-estimates-lua,algo=%s,obs=%s,radius=%s,which=mc/',
           options.algo, options.obs, options.radius)
   elseif options.algo == 'llr' then
      error('llr not yet implemented')
   else
      error('logic')
   end

   local dirResults = 
      dirAnalysis .. cmd:string(programName, 
                                options, 
                                {}) .. '/'

   local directories = {}
   directories.analysis = dirAnalysis
   directories.incompleteEstimates = dirIncompleteEstimates
   directories.features = dirFeatures
   directories.results = dirResults

   return directories
end


--------------------------------------------------------------------------------
-- startLogging: create log file and results directory; start logging
--------------------------------------------------------------------------------

-- ARG
-- dirResults: string, path to directory
-- RETURN
-- log: instance of Log
function startLogging(dirResults)
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
end

--------------------------------------------------------------------------------
-- ApnIndex
--------------------------------------------------------------------------------

-- class to convert APNs to and from row indices
do
   torch.class('ApnIndex')

   function ApnIndex:__init()
      self.apnTable = {}
      self.apnIndex = 0
   end

   function ApnIndex:apn2Index(apn)
      local trace = false
      assert(type(apn) == 'string')
      assert(string.len(apn) == 10)
      local index = self.apnTable[apn]
      if index then return index end  -- have already seen this APN
      self.apnIndex = self.apnIndex + 1
      self.apnTable[apn] = self.apnIndex
      if trace then
         print('ApnIndex:apn2Index apn,index', apn, self.apnIndex)
      end
      return self.apnIndex
   end

   function ApnIndex:index2Apn(index)
      local trace = false
      assert(type(index) == 'number', index)
      assert(index > 0, index)
      if self.indexTable == nil then self:_makeIndexTable() end
      local apn = self.indexTable[index]
      assert(apn, string.format('ApnIndex:index2Apn index %f not found', index))
      if trace then
         print('ApnIndex:index2Apn index,apn', index, apn)
      end
      return apn
   end

   function ApnIndex:_makeIndexTable()
      local trace = false
      self.indexTable = {}
      for k, v in pairs(self.apnTable) do
         self.indexTable[v] = k
      end
      if trace then 
         print('ApnIndex:_makeIndexTable: indexTable')
         print(self.indexTable)
      end
   end
end

do -- unit test of methods apn2Index and index2Apn
   local apnIndex = ApnIndex()

   local function checkIndex(expectedIndex, apn)
      local actualIndex = apnIndex:apn2Index(apn)
      assertEqual(expectedIndex, actualIndex)
   end

   local function checkApn(expectedApn, index)
      local actualApn = apnIndex:index2Apn(index)
      assertEqual(expectedApn, actualApn)
   end

   checkIndex(1, '1230000000')
   checkIndex(1, '1230000000')
   checkIndex(2, '4560000000')
   checkIndex(1, '1230000000')
   checkIndex(2, '4560000000')
   checkIndex(3, '7890000000')

   checkApn('1230000000', 1)
   checkApn('4560000000', 2)
   checkApn('7890000000', 3)
end


--------------------------------------------------------------------------------
--- date2Year(date): convert date to year
--------------------------------------------------------------------------------

do 
   -- define function
   function date2Year(date)
      --print('date2Year date', date)
      return math.floor(date / 10000)
   end

   -- unit test function
   local function check(expected, date)
      assertEqual(expected, date2Year(date))
   end

   check(1234, 12345678)
end


--------------------------------------------------------------------------------
-- DateIndex
--------------------------------------------------------------------------------

-- class to convert dates to and from colum indices
do
   torch.class('DateIndex')
   
   function DateIndex:__init(period, firstYear)
      assert(period)
      assert(firstYear)
      self.period = period
      self.firstYear = firstYear
      self.date2IndexTable = {}
      self:_makeDate2IndexTable(period, firstYear)
   end

   function DateIndex:date2Index(date)
      assert(type(date) == 'string')
      assert(string.len(date) == 8)
      local result = self.date2IndexTable[self:_normalize(date)]
      assert(result, date)
      return result
   end

   function DateIndex:index2Date(index)
      assert(type(index) == 'number')
      assert(index > 0)
      if self.index2DateTable == nil then self:_makeIndex2DateTable() end
      local result = self.index2DateTable[index]
      assert(result, index)
      return result
   end

   function DateIndex:_makeDate2IndexTable(period, firstYear)
      local trace = false
      local function maxPeriod()
         if period == 'month' then return 12 else return 4 end
      end
      local function stepPeriod()
         if period == 'month' then return 1 else return 3 end
      end
      local index = 0
      for year = firstYear, 2009 do
         for periodIndex = 1, 12, stepPeriod() do
            index = index + 1
            local normalizedDate = 
               self:_normalize(tostring(year) ..
                               string.format('%02d', periodIndex) ..
                               '15')
            self.date2IndexTable[normalizedDate] = index
            if trace then 
               print('DateIndex:_makeDate2IndexTable normalizedDate,index',
                     normalizedDate, index)
            end
         end
      end
   end

   function DateIndex:_makeIndex2DateTable() 
      self.index2DateTable = {}
      for k, v in pairs(self.date2IndexTable) do
         self.index2DateTable[v] = k
      end
   end

   local quarterTable = {'02', '02', '02', 
                         '05', '05', '05',
                         '08', '08', '08',
                         '11', '11', '11'}

   function DateIndex:_normalize(date)
      assert(type(date) == 'string')
      assert(string.len(date) == 8)
      local year = string.sub(date, 1, 4)
      local month = string.sub(date, 5, 6)
      if self.period == 'quarter' then
         month = quarterTable[tonumber(month)]
      end
      return year .. month .. '15'
   end
end

do -- unit test of methods date2Index and index2Date
   local function check(expectedIndex, period, actualDate)
      local dateIndex = DateIndex(period, 1984)
      local index = dateIndex:date2Index(actualDate)
      assertEqual(expectedIndex, index)
      local expectedNormalizedDate = dateIndex:_normalize(actualDate)
      assertEqual(expectedNormalizedDate, dateIndex:index2Date(index))
   end

   check(1, 'monnth',  '19840102')
   check(1, 'quarter', '19840102')
   check(1, 'quarter', '19840202')
   check(1, 'quarter', '19840302')

   check(2, 'month',   '19840201')
   check(2, 'quarter', '19840401')
   check(2, 'quarter', '19840501')
   check(2, 'quarter', '19840601')

   check(25 * 12 + 1, 'month',   '20090115')
   check(25 * 4 + 1,  'quarter', '20090116')
   check(25 * 4 + 1,  'quarter', '20090205')
   check(25 * 4 + 1,  'quarter', '20090330')

   check(25 * 12 + 12, 'month',   '20091210')
   check(25 * 4 + 4,   'quarter', '20091001')
   check(25 * 4 + 4,   'quarter', '20091128')
   check(25 * 4 + 4,   'quarter', '20091231')

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
-- makeIncompleteMatrix: return IncompleteMatrix for selected dates
--------------------------------------------------------------------------------

-- only save if date is in range [yearFirst, 2009]
-- ARGS:
-- pathInput : path to incomplete matrix file
-- apnIndex  : instance of ApnIndex
-- dateIndex : instance of DateIndex
-- firstYear : number, first year in the incomplete matrix
-- log       : instance of Log
-- options   : table of command line options
-- RETURNS: instance of an IncompleteMatrix
function makeIncompleteMatrix(pathInput, apnIndex, dateIndex, yearFirst, 
                              log, options)
   assert(pathInput)
   assert(apnIndex)
   assert(dateIndex)
   assert(yearFirst)
   assert(log)
   assert(options)

   local trace = true
   if trace then
      print('makeIncompleteMatrix')
      print(' pathInput', pathInput)
      print(' dateIndex', dateIndex)
      print(' yearFirst', yearFirst)
   end
   local start = os.clock()

   -- read input CSV file
   local input = io.open(pathInput)
   if input == nil then
      print('unable to open incomplete estimate file', pathInput)
      os.exit(1)
   end

   local header = input:read() -- don't use the header

   -- convert each valid row in the CSV to an error in the incomplete matrix
   local im = IncompleteMatrix()
   local countSkippedDate = 0
   local countSkippedFormat = 0
   local countSkippedSameElement = 0
   local countUsed = 0
   local countInput = 0

   -- maintain table transactionsFor[apn] = {trans1, ..., transN}
   local transactionsFor = {}
   local function insertTransactionFor(apn, date, actual, estimate)
      local trace = false
      if trace then
         print('insertTransactionFor apn, date, actual, estimate',
               apn, date, actual, estimate)
         print('types', type(apn), type(date), type(actual), type(estimate))
      end
      assert(apn)
      assert(type(apn) == 'string')
      assert(date)
      assert(type(date) == 'string')
      assert(actual)
      assert(type(actual) == 'number')
      assert(estimate)
      assert(type(estimate) == 'number')
      local newValue = {date, actual, estimate}
      local value = transactionsFor[apn]
      if trace then 
         print('insertTransactionFor apn, newValue, value',
               apn, newValue, value)
      end
      if value == nil then
         value = {newValue}
      else
         if trace then print(' value before mutated', value) end
         value[#value + 1] = newValue
         if trace then print(' value after mutated', value) end
      end
      transactionsFor[apn] = value
      if trace then
         print(' apn, transactionsFor[apn]', apn, transactionsFor[apn])
         continue()
      end
   end

   local function summarizeTransactionsFor()
     -- count number of times each number of transactions occurs
      local countOccurs = {}
      
      for apn, transactions in pairs(transactionsFor) do
         --print('apn, transactions', apn, transactions)
         local nTransactions = #transactions
         countOccurs[nTransactions] = (countOccurs[nTransactions] or 0) + 1
      end

      log:log('Number of times APNs traded')
      for count, occurs in pairs(countOccurs) do
         log:log('%10d APNs traded %2d times', occurs, count)
      end
   end


   -- return false if record is invalid
   -- return true, actual, estimate if record is valid
   --   where actual = tonumber(actualString)
   --         estimate = tonumber(estimateString)
   function isGoodInputRecord(apn, date, radius, actualString, estimateString)
      local actual = tonumber(actualString)
      local estimate = tonumber(estimateString)
      if apn == nil or
         string.len(apn) ~= 10 or
         string.len(date) ~= 8 or
         actualString == nil or
         actual == nil or
         estimateString == nil or
         estimate == nil then
         return false
      else
         return true, actual, estimate
      end
   end

   -- read all the usable input data into transactionsFor
   -- only read 1000 if option -test 1 was specified
   for line in input:lines('*l') do
      countInput = countInput + 1
      if options.test == 1 and countInput > 1000 then break end
      local apn, date, radius, actualString, estimateString = 
         string.gmatch(line, '(%d+),(%d+),(%d+),(%d+[%.%d+]*),(%d+[%.%d+]*)')()
      local ok, actual, estimate = 
         isGoodInputRecord(apn, date, radius, actualString, estimateString)
      if ok then
         local year = date2Year(date)
         if yearFirst <= year and year <= 2009 then
            insertTransactionFor(apn, date, actual, estimate)
         else
            countSkippedDate = countSkippedDate + 1
         end
      else
         countSkippedFormat = countSkippedFormat + 1
      end
   end

   -- insert the usable data into the incomplete matrix
   for apn, transactions in pairs(transactionsFor) do
      for transactionNumber, values in ipairs(transactions) do
         --print('transactionNumber, values', transactionNumber, values)
         local date = values[1]
         local actual = values[2]
         local estimate = values[3]
         local added = im:add(apnIndex:apn2Index(apn),     -- rowIndex
                              dateIndex:date2Index(date),  -- colIndex
                              actual - estimate,           -- error
                              false)                       -- verbose
         if added then
            countUsed = countUsed + 1
         else
            countSkippedSameElement = countSkippedSameElement + 1
         end
      end
   end

   summarizeTransactionsFor()

   print(string.format('readEstimates cpu %f\n', os.clock() - start))
   log:log('Read %d data records from incomplete estimates file', countInput)
   log:log(' Used %d estimates from it', countUsed)
   log:log(' Skipped %d records in it because of date', countSkippedDate)
   log:log(' Skipped %d records in it because of format', countSkippedFormat)
   log:log(' Skipped %d records in it because in same row and col',
           countSkippedSameElement)

   return im
end

--------------------------------------------------------------------------------
-- histogram
--------------------------------------------------------------------------------

function histogram(title, t)
   print(title)
   occurs = {}
   for _, count in pairs(t) do
      if occurs[count] == nil then occurs[count] = 0 end
      occurs[count] = occurs[count] + 1
   end
   print(string.format('%5s %6s', 'count', 'occurs'))
   for k, v in pairs(occurs) do
      print(string.format('%5d %6d', k, v))
   end
end

--------------------------------------------------------------------------------
-- printOptions
--------------------------------------------------------------------------------

-- print or log parameters
function printOptions(options, log)
   print('Command line parameters')
   keys = {}
   for k in pairs(options) do
      keys[#keys + 1] = k
   end
   table.sort(keys)
   for i = 1, #keys do
      local key = keys[i]
      local value = options[key]
      local line = string.format('%17s %s', key, value)
      if log then
         log:log(line)
      else
         print(line)
      end
   end
end

--------------------------------------------------------------------------------
-- doCg
-------------------------------------------------------------------------------

-- optimize weights for specified CPU seconds using CG
-- write results to file
-- RETURN
-- lastLoss
-- mutated incomplete matrix
function doCg(writeResultFunction, im, log, phase, method, lambda,
              limitCpuSeconds, rank)
   assert(writeResultFunction)
   assert(im)
   assert(log)
   assert(phase)
   assert(method)
   assert(lambda)
   assert(limitCpuSeconds)
   assert(rank)

   local rho = 0.01
   local sig = 0.5
   local int = 0.1
   local ext = 3.0
   local maxIter = 20
   local ratio = 100
   --local maxEval = 1.25 * maxIter
   local maxEval = 10 * maxIter -- allow more effort on line search
   
   log:log('cg parameters')
   log:log(' rho     %f', rho)
   log:log(' sig     %f', sig)
   log:log(' int     %f', int)
   log:log(' ext     %f', ext)
   log:log(' maxIter %d', maxIter)
   log:log(' ratio   %f', ratio)
   log:log(' maxEval %f', maxEval)

   writeResultFunction(phase, method, 0, im:_opFunc(im.weights,
                                                    lambda,
                                                    'all'))
   
   local timerCpu = TimerCpu()
   local lastLoss
   while (timerCpu:cumSeconds() < limitCpuSeconds) do
      local weights, lossTable = im:cg(rank,
                                       rho, sig,
                                       int, ext,
                                       maxIter, ratio, maxEval,
                                       lambda)
      print('doCG: cg lossTable', lossTable)
      lastLoss = lossTable[#lossTable]
      writeResultFunction(phase, method, timerCpu:cumSeconds(), lastLoss)
   end
   assert(lastLoss)
   return lastLoss, im
end

--------------------------------------------------------------------------------
-- doLbfgs
--------------------------------------------------------------------------------

-- optimize weights for specified CPU seconds using L-BFGS
-- write results to file
-- RETURNS
-- lastLoss
-- mutated incomplete matrix (the ARG im is also mutated)
local function doLbfgs(writeResultFunction, im, log, phase, method, lambda,
                      limitCpuSeconds, rank, justOneIteration)
   -- check that args were provided
   assert(writeResultFunction)
   assert(im)
   assert(log)
   assert(phase)
   assert(method)
   assert(lambda)
   assert(limitCpuSeconds) 
   assert(rank)
   local justOne
   if justOneIteration == nil then 
      justOne = false
   else
      justOne = justOneIteration
   end

   -- define L-BFGS args
   local maxIter = 20
   if justOne then maxIter = 10 end
   local maxEval = 1.25 * maxIter
   local tolFun = 1e-5
   local tolX = 1e-9
   local nCorrection = 100
   local learningRate = 1
   local verboseOptimLbfgs = true

   log:log('lbfgs parameters')
   log:log(' maxIter           %d', maxIter)
   log:log(' maxEval           %f', maxEval)
   log:log(' tolFun            %f', tolFun)
   log:log(' tolX              %f', tolX)
   log:log(' nCorrection       %d', nCorrection)
   log:log(' learningRate      %f', learningRate)
   log:log(' verboseOptimLbfgs %s', tostring(verboseOptimLbfgs))

   -- write starting point after 0 CPU seconds
   writeResultFunction(phase, method, 0, im:_opFunc(im.weights,
                                                    lambda,
                                                    'all'))

   
   local timerCpu = TimerCpu()
   local lastLoss
   while (timerCpu:cumSeconds() < limitCpuSeconds) do
      local weights, lossTable = im:lbfgs(rank,
                                          maxIter, maxEval,
                                          tolFun, tolX,
                                          nCorrection, learningRate,
                                          verboseOptimLbfgs,
                                          lambda)
      print(' doLbfgs lossTable', lossTable)
      lastLoss = lossTable[#lossTable]
      print(' doLbfgs lastLoss', lastLoss)
      writeResultFunction(phase, method, timerCpu:cumSeconds(), lastLoss)
      print(' doLbfgs justOne', justOne)
      if justOne then break end
   end
   assert(lastLoss)
   return lastLoss, im
end -- do Lbfgs

--------------------------------------------------------------------------------
-- doSgd
--------------------------------------------------------------------------------

-- run Stochastic Gradient Descent
-- write one of more records by calling writeResultFunction
-- RETURNS
-- lastLoss   : number
-- im         : mutated IncompleteMatrix (an arg)
-- lossTable : table of losses
local function doSgd(writeResultFunction, im, log, phase, method, lambda,
                     limitCpuSeconds, options)
   assert(writeResultFunction)
   assert(im)
   assert(log)
   assert(phase)
   assert(method)
   assert(lambda)
   assert(limitCpuSeconds)
   assert(options)
   assert(options.learningRate)
   assert(options.learningRateDecay)
   assert(options.rank)

   local weightDecay = 0
   local momentum = 0
   
   log:log('sgd parameters')
   log:log(' learningRate      %f', options.learningRate)
   log:log(' learningRateDecay %f', options.learningRateDecay)
   log:log(' weightDecay       %f', weightDecay)
   log:log(' momentum          %f', momentum)
   
   -- determine initial full gradient
   -- in iteration, use stochastic gradient
   writeResultFunction(phase, method, 0, im:_opFunc(im.weights,
                                                    lambda,
                                                    'all'))

   local timerCpu = TimerCpu()
   local lastLoss
   local allLosses = {}
   while (timerCpu:cumSeconds() < limitCpuSeconds) do
      local weights, lossTable = im:sgd(options.rank,
                                        options.learningRate,
                                        options.learningRateDecay,
                                        weightDecay,
                                        momentum,
                                        lambda)
      assert(1 == #lossTable, lossTable)
      lastLoss = lossTable[#lossTable]
      allLosses[#allLosses + 1] = lastLoss
      writeResultFunction(phase, method, timerCpu:cumSeconds(), lastLoss)
   end
   assert(lastLoss)
   return lastLoss, im, allLosses
end  -- doSgd

--------------------------------------------------------------------------------
-- whichCheckGradient
-------------------------------------------------------------------------------

-- check that the gradient from IncompleteMatrix is correct
function whichCheckGradient(incompleteMatrix)
   print('Checking gradient')
   local rank = 5
   incompleteMatrix:_initializeWeights(rank)
   print('check weights[1][1]', incompleteMatrix.weights[1][1])
   print('check weights:size()', incompleteMatrix.weights:size())
   local weightsNRows = incompleteMatrix.weights:size(1)
   local weightsNCols = incompleteMatrix.weights:size(2)
   local weightsNElements = weightsNRows * weightsNCols

   local nCalls = 0
   local function opfunc(weights)
      local lambda = 0
      local value, gradient = 
         incompleteMatrix:_opFunc(weights:resize(weightsNRows,
                                                 weightsNCols), 
                                     lambda, 
                                     'all')
      nCalls = nCalls + 1
      print(string.format(' whichCheckGradient %d/%d opfunc value', 
                          nCalls, weightsNRows + weightsNCols, value))
      return value, gradient
   end

   local epsilon = 1e-5
   local d, dy, dh = 
      checkGradient(opfunc,
                    incompleteMatrix.weights:resize(weightsNElements),
                    epsilon)

   -- d is supposed to be small, but how small is reasonable?
   print('d', d)
   assert(d < 1, 'checkGradient returned discouraging result')

end -- whichCheckGradient


--------------------------------------------------------------------------------
-- whichComplete
--------------------------------------------------------------------------------

-- complete the matrix:
-- 1. Find the optimal weights using L-BFGS (shown to be fastest) then SGD (to
--    refine)
-- 2. Use weights to estimate the complete matrix
-- 3. Write the complete matrix to all-estimates-mc.csv
function whichComplete(dirResults, 
                       im, 
                       options,
                       log,
                       apnIndex, 
                       dateIndex)
   assert(dirResults)
   assert(im)
   assert(options)
   assert(log)
   assert(apnIndex)
   assert(dateIndex)

   print('in whichComplete')

   function check(field) 
      local value = options[field]
      assert(value)
      return value
   end

   local lambda = check('lambda')
   local radius = check('radius')
   local rank = check('rank')
   local timeLbfgs = check('timeLbfgs')
   local timeSgd = check('timeSgd')
   local sgdLearningRate = check('learningRate')
   local sgdLearningRateDecay = check('learningRateDecay')

   assert(lambda >= 0)
   assert(radius >= 1)
   assert(math.floor(radius) == radius) -- radius is an integer
   assert(rank > 0)
   assert(timeLbfgs > 0)
   assert(timeSgd > 0)

   local pathResultsFile = dirResults .. 'all-estimates-mc.csv'
   log:log('%-30s %s', 'pathResultsFile', pathResultsFile)
   local resultsFile = io.open(pathResultsFile, 'w')
   assert(resultsFile, pathResultsFile)

   -- 1. Find optimal weights
   --    a. Run L-BFGS until loss starts to increase
   --    b. Run SGD for using for timeSgd CPU seconds
   local function writeResultFunction(phase, method, cumElapsedSecs, lastLoss)
      assert(phase)
      assert(method)
      assert(cumElapsedSecs)
      assert(lastLoss)
      local line = string.format('%s,%s,%f,%f',
                                 phase,
                                 method,
                                 cumElapsedSecs,
                                 lastLoss)
      log:log('line: %s', line)
   end -- writeResultFunction

   im:_initializeWeights(rank)

   -- 1a. Run L-BFGS, remember im just before loss increases
   -- NOTE: there are two time limits unfortunately
   -- - One in this code
   -- - One in doLbfgs
   local phase = 'phase1'
   local method = 'lbfgs'
   local timerLbfgs = TimerCpu()
   local prevLoss = math.huge
   local lowestIm = nil
   local countLbfgsIterations = 0
   local justOneIteration = true
   repeat
      local converging
      local currentLoss, mutatedIm = 
         doLbfgs(writeResultFunction, im, log, phase, method, lambda, 
                 timeLbfgs, rank, justOneIteration)
      countLbfgsIterations = countLbfgsIterations + 1
      log:log('L-BFGS iteration %d CPU %f \n current loss %f previous loss %f',
              countLbfgsIterations,
              timerLbfgs:cumSeconds(),
              currentLoss, 
              prevLoss)
      print('whichComplete prevLoss, currentLoss', prevLoss, currentLoss)
      if currentLoss < prevLoss then
         lowestIm = mutatedIm
         prevLoss = currentLoss
         converging = true
      else
         converging = false
      end
   until 
      not converging or
      timerLbfgs:cumSeconds() > timeLbfgs
   
   log:log('For L-BFGS phase, lastLoss = %f', prevLoss)
   local lbfgsRmse = lowestIm:rmse(true)
   log:log('For L-BFGS phase, RMSE = %f', lbfgsRmse)

   -- 1b. Run SGD for timeSgd CPU seconds
   phase = 'phase2'
   method = 'sgd'
   local lbfgsLoss = prevLoss
   lastLoss, mutatedIm, lossTable =
      doSgd(writeResultFunction, lowestIm, log, phase, method, lambda, 
            timeSgd, rank, sgdLearningRate, sgdLearningRateDecay)
   log:log('For phase 2, lastLoss = %f from SGD after %f CPU seconds',
           lastLoss, timeSgd)

   local function findMinLoss(table)
      local minLoss = math.huge
      for _, v in pairs(table) do
         if v < minLoss then minLoss = v end
      end
      return minLoss
   end

   local minLoss = findMinLoss(lossTable)
   log:log('minimum SGD loss = %f', minLoss)
   if minLoss < lastLoss then
      log:log('SGD Losses decreased then increased')
      log:log('Try decreasing learningRateDecay')
   end
   lastRmse = mutatedIm:rmse()
   log:log('RMSE for last weights = % f', lastRmse)
   log:log(' ')
   log:log('last L-BFGS loss = %f', lbfgsLoss)
   log:log('last L-BFGS RMSE = %f', lbfgsRmse)
   log:log(' ')
   log:log('last SGD loss    = %f', lastLoss)
   log:log('last SGD RMSE    = %f', lastRmse)
   log:log(' ')
   log:log('last SGD loss recomputed = %f', mutatedIm:_opFunc(im.weights,
                                                              lambda,
                                                              'all'))
   if lbfgsLoss < lastLoss then
      log:log('aborting, since loss increased in SGD')
      return
   end


   -- 2. Complete the im using the weights
   if options.write == 'no' then
      log:log('Will not complete matrix, since just testing SGD options')
      return
   end
   
   local completed = im:complete()

   -- 3. Write each estimated error to the results CSV file
   resultsFile:write('apn,date,radius,estimatedError\n')
   for rowIndex = 1, im.nRows do
      if rowIndex % 10000 == 0 then
         print('writing rowIndex', rowIndex)
      end
      for colIndex = 1, im.nCols do
         local line = string.format('%s,%s,%s,%s\n',
                                    apnIndex:index2Apn(rowIndex),
                                    dateIndex:index2Date(colIndex),
                                    radius,
                                    completed[rowIndex][colIndex])
         resultsFile:write(line)
      end
   end
   resultsFile:close()
   
end  -- whichComplete

--------------------------------------------------------------------------------
-- lossVsCpu
--------------------------------------------------------------------------------

-- determine and write lossVsCpu for the IncompleteMatrix
-- run as many iterations of the method as possible
-- stop after timeLimit CPU second
-- write records to resultsFile
-- RETURN 
-- lastLoss = loss after timeLimit CPU seconds
-- lastIm = last IncompleteMatrix found in iterations
function lossVsCpu(im, method, phase, timeLimit, 
                   lambda, resultsFile, log, options)
   assert(im)
   assert(method)
   assert(phase)
   assert(timeLimit)
   assert(lambda)
   assert(resultsFile)
   assert(log)
   assert(options)
   
   if type(method) ~= 'string' then
      print('bad method type')
      print('expected string, got ' .. type(method))
      print('method', method)
      assert(false)
   end

   local function writeResult(phase, 
                              method, 
                              cumElapsedSeconds, 
                              loss)
      local line = string.format('%s,%s,%f,%f\n',
                                 phase,
                                 method,
                                 cumElapsedSeconds,
                                 loss)
      print('line', line)
      resultsFile:write(line)
   end
   
   -- run one of the methods, but don't change the ARG im
   if method == 'cg' then
      local clone = im:clone()
      return 
         doCg(writeResult, im:clone(), log, phase, method, lambda, 
              timeLimit, rank)
   elseif method == 'lbfgs' then
      local clone = im:clone()
      return 
         doLbfgs(writeResult, im:clone(), log, phase, method, lambda, 
                 timeLimit, options.rank)
   elseif method == 'sgd' then
      local clone = im:clone()
      return 
         doSgd(writeResult, im:clone(), log, phase, method, lambda, 
               timeLimit, options)
   else
      print('method', method)
      assert(false, 'logic error:' .. method)
   end
end -- lossVsCpu


--------------------------------------------------------------------------------
-- whichTime
--------------------------------------------------------------------------------

-- run timing experiment
-- write results to RESULTS/timing.gnuplot  NOTE: not done at present?
-- columns
--  phase: in {'beginning', 'after 1 hour'}
--  method: in {'cg', 'lbfgs', 'sgd'}
--  cpuSec: number of cpu seconds used by phase x method
--  loss:   loss after that many seconds
-- ARGS:
-- dirResult : string, path to directory where the o
function whichTime(dirResult, im, rank, phase1Time, phase2Time, log)
   local trace = true
   if trace then
      print('whichTime')
      print(' dirResults', dirResult)
      print(' im', im.self)
      print(' rank', rank)
   end

   assert(dirResult)
   assert(im)
   assert(rank)
   assert(phase1Time)
   assert(phase2Time)

   local pathResultsFile = dirResult .. 'timing.gnuplot'
   log:log('%-16s %s', 'pathResultsFile', pathResultsFile)
   local resultsFile = io.open(pathResultsFile, 'w')
   assert(resultsFile, 'did not open: ' .. pathResultsFile)
   resultsFile:write('phase,optimMethod,cumCpuSecs,loss\n')

   log:log('timings are for')
   log:log(' rank %d', rank)

   local lambda = 0.001
   log:log(' L2 regularizer weight %f', lambda)

	
   local methods = {'cg', 'sgd', 'lbfgs'}
   methods = {'cg'} -- FIXME: to debug cg
   methods = {'sgd', 'lbfgs'}  -- CG omitted, since it makes no progress
   if options.justLbfgs == 1 then
      methods = {'lbfgs'}
   end

   -- phase 1: compare methods from same starting point
   im:_initializeWeights(rank)
   local initialTimeLimit = phase1Time
   -- NOTE: 2 successive runs on one method will typically produce difference
   -- results because of the random initialization of the weights
   phase1Results = {}
   initialIm = im
   for _, method in ipairs(methods) do
      local im = initialIm
      local sgdLearningRate = nil
      local lastLoss, lastIm = 
         lossVsCpu(im, method, 'beginning', initialTimeLimit, 
                   lambda, resultsFile, log, options)
      phase1Results[method] = {lastLoss, lastIm}
      print('phase1Results', method, phase1Results[method])
   end
   
   -- determine best method in Phase 1 unless options.time2 is 0
   if options.time2 == 0 then
      log:log('Phase 2 not run because options.time2=%f', options.time2)
   else
      local bestLastLostKey 
      local bestLastLost
      log:log('Phase 1 results summary')
      for k, v in pairs(phase1Results) do
         log:log(' %5s last loss %f', k, v[1])
         if bestLastLost == nil or v[1] < bestLastLost then
            bestLastLostKey = k
            bestLastLost = v[1]
         end
      end
      print('bestLastLostKey', bestLastLostKey)
      
      
      -- phase 2: compare methods starting at best phase 1 result
      local bestIm = phase1Results[bestLastLostKey][2]
      local phase2Results = {}
      print('bestIm', bestIm)
      local secondTimeLimit = phase2Time
      for _, method in pairs(methods) do
         local lastLoss, lastIm = 
            lossVsCpu(bestIm, method, 'continuing', secondTimeLimit, 
                      lambda, resultsFile, rank, log)
            phase2Results[method] = {lastLoss, lastIm}
      end
   
      log:log('Phase 2 results summary')
      for k, v in pairs(phase2Results) do
         log:log(' %s last loss %f', k, v[1])
      end
   end

end -- function whichTime

--------------------------------------------------------------------------------
-- makePaths
--------------------------------------------------------------------------------

-- return table containing paths to input files with these fields
-- .apns
-- .dates
-- .features 
-- .prices
function makePaths(directories, options)
   assert(directories)
   assert(options)

   paths = {}

   if options.algo == 'knn' or options.algo == 'kwavg' then
      paths.incompleteEstimates = 
         directories.incompleteEstimates .. 'estimates-mc.csv' 
   elseif options.algo == 'llr' then
      error('llr not yet implemented')
   else
      error('bad options.algo=' .. tostring(options.algo))
   end

   return paths
end -- makePaths

--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

local cmd, options = readCommandLine(arg)

-- set random number seeds
torch.manualSeed(options.seed)
math.random(options.seed)



local directories = setupDirectories(cmd, options)
local log = startLogging(directories.results)

-- log the command line parameters
printOptions(options, log)

-- log directories used
log:log('\nDirectories used')
for k, v in pairs(directories) do
   log:log('%-20s = %s', k, v)
end

local paths = makePaths(directories, options)
log:log('\nPaths to files')
for k, v in pairs(paths) do
   log:log('%-25s = %s', k, v)
end

-- define how to convert dates to column indices and APNs to row indices
local apnIndex = ApnIndex()
local dateIndex = DateIndex(options.col, options.yearFirst)

-- read incomplete estimates
incompleteMatrix = makeIncompleteMatrix(paths.incompleteEstimates,
                                        apnIndex, dateIndex,
                                        options.yearFirst,
                                        log,
                                        options)
print('incompleteMatrix', incompleteMatrix)


-- do whichever computation was requested
if options.which == 'checkGradient' then
   whichCheckGradient(incompleteMatrix)
elseif options.which == 'complete' then
   whichComplete(directories.results, 
                 incompleteMatrix, 
                 options, 
                 log,
                 apnIndex, 
                 dateIndex)
elseif options.which == 'time' then -- TODO: increase time to 1 hour
   whichTime(directories.results, incompleteMatrix, options.rank,
             options.time1, options.time2, log)
end

printOptions(options, log)

if options.test == 1 then 
   log:log('TESTING')
end

log:log('\nfinished')
log:close()







