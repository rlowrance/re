-- create-estimates.lua  changed on bigone
-- create either the Laufer estimates or the Matric Completion estimates

-- Laufer estimates: all APNS in
--   . years 2000, 2001, ..., 2009
--   . mid-point of quarters Q1, ..., Q4 
-- schema: apn, date, radius, estimatedPrice

-- Matrix completion estimates: for each actual transaction (APN,date)
-- in 2000, 2001, ... 2009
-- schema: apn, date, radius, estimatedPrice

-- optimal radius settings
-- algo    knn
-- obs     1A
-- radius* 24

require 'assertEqual'
require 'CsvUtils'
require 'daysPastEpoch'
require 'printOptions'
require 'Knn'
require 'Kwavg'
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
-- readCommandLine
--------------------------------------------------------------------------------

-- validate command line paramters and print them on stdout
-- RETURN
-- cmd object
-- table of parameters
function readCommandLine(args)
   local cmd = torch.CmdLine()
   cmd:text('Create estimates ')
   cmd:text()
   cmd:text('Write csv file ANALYSIS/estimates.csv with fields')
   cmd:text(' apn')
   cmd:text(' date:  mid-quarter dates for 2000, 2001, ..., 2009')
   cmd:text(' radius: k value (for knn) or kernel radius')
   cmd:text(' estimate: estimated price of APN on specified date')
   cmd:text()
   cmd:text('To run:')
   cmd:text(' cd src/lua');
   cmd:text(' torch create-estimates.lua OPTIONS')
   cmd:text()
   cmd:text('OPTIONS')
   cmd:option('-algo','','For now just "knn"; eventually also "kwavg", "llr"')
   cmd:option('-dataDir', '../../data/', 'Path to data directory')
   cmd:option('-debug'  ,0, 'set to 1 to debug')
   cmd:option('-nShards',0,'number of shards')
   cmd:option('-obs','', 'Observation set; for now just "1A"')
   cmd:option('-radius',0,'number of neighbors or kernel radius')
   cmd:option('-seed', 27, 'random number seed')
   cmd:option('-shard',0,'shared number to create')
   cmd:option('-test', 0, 'set to 1 to test')
   cmd:option('-which','', '"laufer" or "mc"')
   print('args', args)
   options = cmd:parse(args)
   
   printOptions(options)

   -- check for missing parameters
   function missing(name) error('missing parameter - ' .. name) end
   if options.algo == '' then missing('algo') end
   if options.nShards == 0 then
      if options.shard ~= 0 then
         error('-shard required if -nShards used')
      end
   end
   if options.radius == 0 then missing('radius') end
   if options.obs == '' then missing('obs') end
   if options.shard == 0 then
      if options.nShards ~= 0 then
         error('-nShards required if -shard used')
      end
   end
   if options.which == '' then missing('which') end

   -- check parameter values
   local function assertElementOf(x, list)
      for _, element in pairs(list) do
         if x == element then return end
      end
      error(x .. ' not in ' .. list)
   end

   assertElementOf(options.algo, {'knn', 'kwavg', 'llr'})
   assert(math.floor(options.nShards) == options.nShards,
          '-nShards is a non-negative integer')
   assertElementOf(options.obs, {'1A', '2R', '2A'})
   assert(math.floor(options.shard) == options.shard,
          '-shard is a non-negative integer')
   assertElementOf(options.which, {'laufer', 'mc'})

   assert(options.radius > 0, '-radius not positive')

   -- set global variable DEBUGGING for ease of adding debugging code
   if options.debug == 1 then
      DEBUGGING = true
   elseif options.debug == 0 then
      DEBUGGING = false
   else
      error('-debuging must be 0 or 1')
   end

   -- set global variable TESTING for ease of adding debugging code
   if options.test == 1 then
      TESTING = true
   elseif options.debug == 0 then
      TESTING = false
   else
      error('-debuging must be 0 or 1')
   end

   return cmd, options
end

--------------------------------------------------------------------------------
-- setupDirectories
--------------------------------------------------------------------------------
   
-- ARGS
-- cmd: CmdLine object used to parse args
-- options: table of parsed command line parameters
-- RETURNS table of directories with these fields
-- .analysis
-- .features
-- .obs
-- .results
function setupDirectories(cmd, options)
   -- setup directories
   local result = {}
   result.obs = options.dataDir .. 'generated-v4/obs' .. options.obs .. '/'
   result.analysis = result.obs .. 'analysis/'
   result.features = result.obs .. 'features/'
   result.results = 
      result.analysis .. cmd:string('create-estimates-lua', 
                                    options, 
                                    {}) .. '/'
   return result
end

--------------------------------------------------------------------------------
-- startLogging
--------------------------------------------------------------------------------

-- create log file and results directory and start logging
-- ARG
-- dirResults: string, path to directory
-- RETURN
-- log: instance of Log
function startLogging(dirResults)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if already exists
   if not os.execute(command) then 
      print('results directory not created', command)
      halt()
   end

   local log = Log(dirResults .. 'log.txt', options)
   log:log('log started on ' .. os.date())
   return log
end

--------------------------------------------------------------------------------
--- date2Year(date): convert date to year
--------------------------------------------------------------------------------

do 
   -- define function
   function date2Year(date)
      return math.floor(date / 10000)
   end

   -- unit test function
   local function check(expected, date)
      assertEqual(expected, date2Year(date))
   end

   check(1234, 12345678)
end

--------------------------------------------------------------------------------
-- makeDateNumber: return number: year + month + 15
--------------------------------------------------------------------------------

makeDateNumberMonths = {2,5,8,11}
function makeDateNumber(year, quarter)
   return year * 10000 + makeDateNumberMonths[quarter] * 100 + 15
end

--------------------------------------------------------------------------------
-- split: return table containing elements of string separated by sep
--------------------------------------------------------------------------------

-- ref: http://www.lua.org/manual/5.1/manual.html#pdf-string.gmatch
function split(str, sep)
   t = {}
   -- field name consists of seq of letters, numbers, hyphens
   for fieldName in string.gmatch(str, '([%a%n-]+)') do
      t[#t + 1] = fieldName
   end
   return t
end

--------------------------------------------------------------------------------
-- meanStdv
--------------------------------------------------------------------------------

-- return mean, standard deviation of values in a Tensor
function meanStdv(t)
   local mean = torch.sum(t) / t:size(1)
   local stdv = torch.std(t)  -- normalize by N - 1
   return mean, stdv
end

--------------------------------------------------------------------------------
-- traceHead: print first few entries
--------------------------------------------------------------------------------

function traceHead(pause, name, a, count)
   if count == nil then count = 10 end
   for i = 1, count do
      print(name, i, a[i])
   end
   if pause then continue() end
end

--------------------------------------------------------------------------------
-- readInputs
--------------------------------------------------------------------------------

-- read and validate input
-- ARGS
-- dirFeatures : string, path to features directory
-- RETURN table inputs with these fields
-- .apns       : 1D Tensor of numbers, house identifiers
-- .dates      : 1D Tensor of numbers, dates of transactions (YYYYMMDD)
-- .features   : 2D Tensor, each row a sample
-- .prices     : 1D Tensor, log(prices)
-- .dateColumn : number, column number in features containing date
function readInputs(dirFeatures)
   local tracing = false
   local printing = true
   local pausing = false

   local function maybePrint(name, value, count)
      if printing then
         traceHead(pausing, name, value,count)
      end
   end

   print('reading csv files')
   local inputs = {}

   -- possibly set a throttle on number of input records read
   local inputLimit = 0
   if TESTING then inputLimit = 1000 end
   
   local hasHeader = true
   inputs.apns = CsvUtils():read1Number(dirFeatures .. 'apns.csv', 
                                        hasHeader,
                                        '1D Tensor',
                                        inputLimit)
   maybePrint('apns', inputs.apns)
   assert(torch.typename(inputs.apns) == 'torch.DoubleTensor',
          'type(apns)=' .. type(inputs.apns))
   
   inputs.prices = CsvUtils():read1Number(dirFeatures .. 'SALE-AMOUNT-log.csv',
                                         hasHeader,
                                         '1D Tensor',
                                         inputLimit)
   maybePrint('prices', inputs.prices)
   
   -- features.csv drops the redundant 1-of-k encoded column
   -- features is an array of Tensors
   local hasHeader = true
   local returnKind = '2D Tensor'
   local featuresHeaderString
   inputs.features, featuresHeaderString = 
      CsvUtils():readNumbers(dirFeatures .. 'features.csv', 
                             hasHeader, 
                             returnKind,
                             inputLimit)
   print('features sizes:', inputs.features:size(1), inputs.features:size(2))
   maybePrint('features', inputs.features, 1)
   
   local featuresColumns = #(inputs.features[1])
   local featuresHeaders = split(featuresHeaderString, ",")
   
   -- determine column that contains the day standardized feature
   inputs.dateColumn = 6
   assert('day-std' == featuresHeaders[inputs.dateColumn])
   
   -- read dates and days
   inputs.dates = CsvUtils():read1Number(dirFeatures .. 'date.csv', 
                                        hasHeader,
                                        '1D Tensor',
                                        inputLimit)
   maybePrint('dates', inputs.dates)

   if printing then print('dateColumn', inputs.dateColumn) end
   
   return inputs
end -- readInputs

--------------------------------------------------------------------------------
-- makeQuery return a query as a 1d Tensor, adjusting its date 
--------------------------------------------------------------------------------

-- ARGS
-- dayStd   : function to convert a day number to a standardized day number
-- date     : number, YYYYMMDD date of transaction
-- features : 2D Tensor
-- obsIndex : 1 <= integer <= features:size(1), transaction being updated
-- RETURN 
-- 1d Tensor features[obsIndex] with updated transaction date
function makeQuery(inputs, options, dayStd, date, obsIndex)
   local trace = false

   assert(inputs)
   assert(options)
   assert(dayStd)
   assert(date)
   assert(obsIndex)

   assert(torch.typename(inputs.features) == 'torch.DoubleTensor',
          'type=' .. type(inputs.features) .. 
          ' typename=' .. torch.typename(inputs.features))
   assert(inputs.features:dim() == 2)

   local daysPastEpoch = daysPastEpoch(date)
   local dayStd = dayStd(daysPastEpoch)
   --print('features',features)
   --print('obsIndex', obsIndex)
   local result = inputs.features[obsIndex]:clone()  -- [i] creates a view!
   --print('result', result)
   --print('typename(result)', torch.typename(result))
   --print('result:dim()', result:dim())
   local priorDayStd = result[inputs.dateColumn]
   result[inputs.dateColumn] = dayStd
   if trace then
      print('makeQuery')
      print(' dayStd', dayStd)
      print(' date', date)
      --print(' features', features)
      print(' obsIndex', obsIndex)
      print(' result', result)
      print(' type result', torch.typename(result))
      continue()
   end
   return result
end --makeQuery

--------------------------------------------------------------------------------
-- estimateKnn return estimate price for a query
--------------------------------------------------------------------------------

-- return estimate using k nearest neighbors
-- RETURNS
-- true, estimate
-- false, reason
function estimateKnn(inputs, options,
                     dayStd, queryIndex, transactionDate)
   local trace = false

   assert(inputs)
   assert(options)
   assert(dayStd)
   assert(queryIndex)
   assert(transactionDate)

   local me = 'estimateKnn'
   local benchmark = false
   local debugAvoidSort = false
   local timer = torch.Timer()
   if true and trace then 
      print('estimateKnn')
      print(' dayStd', dayStd)
      --print(' features', features)
      print(' queryIndex', queryIndex)
      print(' radius', radius)
      print(' transactionDate', transactionDate)
   end

   local query = makeQuery(inputs, options,
                           dayStd, transactionDate, queryIndex)
   if trace then 
      print(me, 'query', queryIndex, transactionDate, query) 
   end
   if brenchmark then 
      print('estimateKnn: built query in', timer:time().user)
      timer:reset()
   end

   if benchmark then 
      -- determine indices of the distance-ordered features
      -- use the slow method of checking each features[obsIndex] 1 at a time
      local dist1 = torch.Tensor(features:size(1)):zero()
      for obsIndex = 1, features:size(1) do
         if obsIndex == 1 then
            print('obsIndex', obsIndex,
                  'features[obsIndex]', features[obsIndex])
            print('query', query)
         end
         dist1[obsIndex] = torch.dist(query, features[obsIndex])
         if obsIndex < 10 then
            print('obsIndex', obsIndex, 'dist1[obsIndex]', dist1[obsIndex])
         end
      end

      local _, sortedIndices =  torch.sort(dist1) -- sort in ascending order

      -- find the average of the k nearest neighbors
      local sumPrices = 0
      for k = 1, radius do
         sumPrices = sumPrices + prices[sortedIndices[k]]
      end
      estimate1 = sumPrices / radius  -- not a local

      print(string.format('estimateKnn: estimate1 (%f) in %f',
                          estimate1, timer:time().user))
      timer:reset()
   end

   local knn = Knn
   local ok, estimate2 = knn:estimate(inputs.features, 
                                      inputs.prices, 
                                      query, 
                                      options.radius)
   if not ok then
      return false, estimate2
   end
   if benchmark then 
      print(string.format('estimateKnn: estimate2 (%f) in %f',
                          estimate2, timer:time().user))
      timer:reset()
      print('type(estimate1', type(estimate1))
      print('type(estimate2', type(estimate2))

      assert(math.abs(estimate1 -  estimate2) < 1e-5)
   end

   return true, estimate2

end -- estimateKnn

--------------------------------------------------------------------------------
-- estimateKwavg
--------------------------------------------------------------------------------

-- return estimate use kernel-weighted average
-- RETURNS 
-- true, estimate
-- false, reason
function estimateKwavg(inputs, options,
                       dayStd, queryIndex, transactionDate)
   assert(inputs)
   assert(options)
   assert(dayStd)
   assert(queryIndex)
   assert(transactionDate)
   
   local query = makeQuery(inputs, 
                           options, 
                           dayStd, 
                           transactionDate, 
                           queryIndex)
   local kwavg = Kwavg('epanechnikov quadratic')
   local ok, estimate = kwavg:estimate(inputs.features, 
                                       inputs.prices, 
                                       query, 
                                       options.radius)
   return ok, estimate
end --estimateKwavg

--------------------------------------------------------------------------------
-- estimate
--------------------------------------------------------------------------------

-- RETURNS
-- true, estimate OR
-- false, reason
function estimate(inputs, options, dayStd, queryIndex, transactionDate)
   local trace = false

   assert(inputs)
   assert(options)
   assert(dayStd)
   assert(queryIndex)
   assert(transactionDate)

   if trace then
      print('estimate')
      print(' algo', algo)
      print(' dayStd', dayStd)
      --print(' features', features')
      print(' queryIndex', queryIndex)
      print(' radius', radius)
      print(' transactionDate', transactionDate)
      print(' dateColumn', dateColumn)
   end

   if options.algo == 'knn' then
      return estimateKnn(inputs,
                         options,
                         dayStd, 
                         queryIndex, 
                         transactionDate)
   elseif options.algo == 'kwavg' then
      return estimateKwavg(inputs,
                           options,
                           dayStd,
                           queryIndex, 
                           transactionDate)
   elseif options.algo == 'llr' then
      error('llr not yet implemented')
   else
      error('logic error')
   end
end -- estimate

--------------------------------------------------------------------------------
-- createLaufer: create CSV file with Laufer's estimates
--------------------------------------------------------------------------------

-- create file with Laufer's estimates
-- write file directories.results/estimates-laufer.csv
-- do just 2000, 2001, ..., 2009, because that what Laufer did
-- write to CSV file directories.results
-- ARGS
-- directories    : table with names of directories
-- inputs         : table of input files
-- options        : table of command line options
-- standardizeDay : function, convert day to standardized day
-- log            : instance of Log class
-- RESULTS: nil
function createLaufer(directories, inputs, options,
                      standardizeDay, log)
   local trace = true

   assert(directories)
   assert(inputs) 
   assert(inputs.apns) 
   assert(inputs.features)
   assert(options)
   assert(standardizeDay)
   assert(log)

   local resultsFileName = directories.results .. 'estimates-laufer.csv'
   local resultsFile =  assert(io.open(resultsFileName, 'w'),
                               'failed to open output file')
   -- if sharding, don't write the csv header, so that results files are
   -- easier to merge
   print('options', options)
   if options.nShards == 0 then
      print('write header')
      resultsFile:write('apn,date,radius,estimate\n')
   end

   -- return true if and only if apn is in the shard or there are no shards
   local function inShard(apn)
      local trace = false
      if trace then
         print(string.format('inShard\n apn %q', apn))
      end
      if options.nShards == 0 then
         if trace then print('result', true) end
         return true
         else
            local result = 
               (tonumber(apn) % options.nShards + 1) == options.shard
            if trace then print(' result', result) end
            return result
      end
   end

   -- count number of unique APNs in the shard
   local nUniqueApns = 0
   do
      local apnsDone = {}
      for obsIndex = 1, inputs.features:size(1) do
         local apn = inputs.apns[obsIndex]
         if inShard(apn) then
            if not apnsDone[apn] then
               nUniqueApns = nUniqueApns + 1
               apnsDone[apn] = true
            end
         end
      end
   end
   print('createLaufer nUniqueApns in shard', nUniqueApns)




   -- estimate APN's value for each year and quarter of interest
   local function estimateApn(apn, nApnsEstimated, obsIndex)
      assert(apn)
      assert(nApnsEstimated)
      assert(obsIndex)
      local timerApn = torch.Timer()
      local ok
      local estimatedPrice
      for year = 2000, 2009 do
         for quarter = 1, 4 do
            local transactionDate = makeDateNumber(year, quarter)
            local timerEstimate = torch.Timer()
            ok, estimatedPrice = estimate(inputs,
                                          options,
                                          standardizeDay,
                                          obsIndex,
                                          transactionDate)
            if ok then
               local line = string.format('%d,%d,%d,%f\n',
                                          apn, 
                                       transactionDate, 
                                       options.radius, 
                                       estimatedPrice)
               resultsFile:write(line)
            else
               log:log('createLaufer: no estimate for APN %s ' ..
                       'year %d quarter %d\n reason=', 
                       apn, year, quarter, estimatedPrice)
            end

               -- avoid a bug in torch by explicitly collecting the garbage
            collectgarbage('collect')
         end
      end
      if trace and ok then
         local elapsed = timerApn:time()
         print(string.format('createLaufer %d/%d %d/%d %d %f %f %f',
                             options.shard, options.nShards,
                             nApnsEstimated, nUniqueApns, 
                             apn, estimatedPrice, 
                             elapsed.real, elapsed.user + elapsed.sys))
      end
   end -- estimateApn
   
   local apnsDone = {}
   local nApnsEstimated = 0
   
   for obsIndex = 1, inputs.features:size(1) do
      local apn = inputs.apns[obsIndex]
      if inShard(apn) then
         if not apnsDone[apn] then
            nApnsEstimated = nApnsEstimated + 1
            apnsDone[apn] = true
            estimateApn(apn, nApnsEstimated, obsIndex)
         end
      end
   end
   
   resultsFile:close()
end

--------------------------------------------------------------------------------
-- createMc: create CSV file containing Matrix Completion estimates
--------------------------------------------------------------------------------

-- do all transactions for all dates, 
-- because more is better for matrix completion
function createMc(directories, inputs, options,
                  standardizeDay, log)
   local me = 'createMc'
   local trace = true

   assert(directories)
   assert(inputs)
   assert(options)
   assert(standardizeDay)
   assert(log)

   -- define how to apply a function to each test transaction
   local nSamples = inputs.features:size(1)
   function eachTestTransaction(apply)
      for obsIndex = 1, nSamples do
         local transactionDate = 
            inputs.dates[obsIndex] -- actual date of transaction
         --local year = date2Year(transactionDate)
         apply(obsIndex, transactionDate)
      end
   end

   -- count number of test transactions
   local nTestTransactions = 0
   function countTests(obsIndex, transactionDate)
      nTestTransactions = nTestTransactions + 1
   end
   eachTestTransaction(countTests)
   print('createMC nTestTransactions', nTestTransactions)
   
   -- estimate each test transaction
   local dirResults = directories.results
   local resultsFile = assert(io.open(dirResults .. 'estimates-mc.csv', 'w'),
                              'failed to open output file')
   resultsFile:write('apn,date,radius,actual,estimate\n')

   local nEstimated = 0
   local line
   function estimateTests(obsIndex, transactionDate)
      local timer = torch.Timer()
      local ok, estimatedPrice = estimate(inputs,
                                          options,
                                          standardizeDay,
                                          obsIndex,
                                          transactionDate)
      if ok then
         line = string.format('%d,%d,%d,%f,%f\n',
                              inputs.apns[obsIndex], 
                              transactionDate, 
                              options.radius,
                              inputs.prices[obsIndex],
                              estimatedPrice)
         resultsFile:write(line)
         nEstimated = nEstimated + 1
      else
         log:log('createMc: no estimate for obsIndex %d transactionDate %s' ..
                 '\n reason %s',
                 obsIndex, transactionDate, estimatedPrice)
      end
      if trace then
         local elapsed = timer:time()
         print(string.format('createMc %d/%d %s wall clock %f CPU %f',
                             nEstimated, 
                             nTestTransactions,
                             line,
                             elapsed.real, 
                             (elapsed.sys + elapsed.user)))
      end
      collectgarbage('collect') -- avoid bug in torch
   end
   eachTestTransaction(estimateTests)
   resultsFile:close()
   assert(nEstimated == nTestTransactions)

   log:log('MC results')
   log:log(' number of samples', nSamples)
   log:log(' number of test transactions', nTestTransactions)
end


--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

local cmd, options = readCommandLine(arg)

-- set random number seeds
torch.manualSeed(options.seed)
math.random(options.seed)

local directories = 
   setupDirectories(cmd, options)
local log = startLogging(directories.results)

-- log the command line parameters
printOptions(options, log)

-- log the directories
log:log('\ndirectories used')
for k, v in pairs(directories) do
   log:log(' %11s = %s', 'dirAnalysis', k, v)
end

local inputs = readInputs(directories.features)

-- validate the input dimensions
do 
   local nSamples = inputs.features:size(1)
   local nDims = inputs.features:size(2)
   local function check(value, expectedSize)
      assert(value)
      assert(expectedSize)
      assert(torch.typename(value) == 'torch.DoubleTensor', 
             'typename=' .. torch.typename(value))
      assert(1 == value:dim())
      assert(expectedSize == value:size(1))
   end
   --print('apns', apns)
   --print('torch.typename(apns)', torch.typename(apns))
   --print('type(apns)', type(apns))
   check(inputs.apns, nSamples)
   check(inputs.dates, nSamples)
   check(inputs.prices, nSamples)
   assert(nDims >= 1)
   assert(1 <= inputs.dateColumn and inputs.dateColumn <= nDims)
end

-- convert the dates to standardized days past an epoch long ago
--local days = datesToDays(dates)
local days = inputs.dates:clone():apply(daysPastEpoch)
for i = 1, 10 do
   print(string.format('dates[%d] %f days[%d] %f',
                       i, inputs.dates[i], i, days[i]))
end

local daysMean, daysStdv = meanStdv(days)
print('daysMean, daysStdv', daysMean, daysStdv)

local function standardizeDay(day)
   return (day - daysMean) / daysStdv
end

-- replace features[*][days] with newly computed values
-- NOTE: this avoids having to decode how the day-std feature was built
print('replacing old standardized day numbers with new ones')
for i = 1, inputs.features:size(1) do
   local oldValue = inputs.features[i][inputs.dateColumn]
   inputs.features[i][inputs.dateColumn] = standardizeDay(days[i])
   if i <= 10 then 
      print(string.format('days[%d] %f ' .. 
                          'old features[%d][%d] %f ' .. 
                          'new features[%d][%d] %f',
                          i, days[i], 
                          i, inputs.dateColumn, oldValue,
                          i, inputs.dateColumn, 
                          inputs.features[i][inputs.dateColumn]))
   end
end

if options.which == 'laufer' then
   createLaufer(directories, inputs, options,
                standardizeDay, log)
elseif options.which == 'mc' then
   createMc(directories, inputs, options,
            standardizeDay, log)
else
   halt("bad options.which")
end

printOptions(options, log)
if DEBUGGING then
   log:log('DEBUGGING')
end

log:log('finished at ' .. os.date())
log:close()
