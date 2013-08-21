-- compare-estimates.lua
-- compare my estimates with Laufer's for actual transactions in 2000 .. 2009
-- write results to a log.txt in the results directory

-- NOTE: the actual transactions do not frequently occur on mid-quarter dates
-- So the analysis is done twice:
-- 1. Use only the actual transactions (about 156 of them)
-- 2. Redate each actual transaction to mid-quarter and use that (about XXX 
--    of them)

-- input files:
-- FEATURES/apns.csv
-- FEATURES/dates.csv
-- FEATURES/prices.csv
-- DATA/laufer-2012-03-hpi-values/hipvalues.txt
-- DATA/generated-v4/obsOBS/analysis/create-estimates-lau...-which=laufer/estimates-laufer.csv

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
   cmd:text("Compare my estimtes, Laufer's, and actual transactions")
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-algo','','Name of algorithm ("knn")')
   cmd:option('-dataDir','../../data/','Path to data directory')
   cmd:option('-radius','','Value of radius parameter')
   cmd:option('-stage',  0, '1 or 2')
   cmd:option('-obs','', 'Observation set')

   -- debugging-related options
   cmd:option('-limitEstimates',0,
              'If not zero, only this many records from' .. 
                 ' Laufer and Roy estimates are saved') 
   -- try 500,000 for 1 estimates
   -- try 535,850 for 2 estimates
   -- 535,850 -> 3
   -- 537,000 -> 4
   -- 538,000 -> 5
   -- 539,000 -> 8
   cmd:option('-trackApn','','Special APN to track (debugging only)')
   cmd:text()

   -- parse command line
   params = cmd:parse(arg)

   printParams(params)


   -- check for missing required command line parameters
   function missing(name)
      error('missing parameter -' .. name)
   end

   if params.algo == '' then missing('algo') end
   if params.dataDir == '' then missing('dataDir') end
   if params.features == '' then missing('features') end
   if params.obs == '' then missing('obs') end

   -- check for allowed parameter values
   if params.limitEstimates < 0 then 
      error('-limitEstimates must be positive') 
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
-- setupInputPaths
--------------------------------------------------------------------------------

-- RETURNS
-- pathLaufer : string, path to Laufer's HPI estimates
-- pathRoy    : string, path to Roy's stage 1 or stage 2 estimates
function setupInputPaths(dirAnalysis, log, params)
   local pathLaufer = 
      params.dataDir ..  'laufer-2012-03-hpi-values/hpivalues.txt'

   -- name of directory with Roy's estimates depends on algorithm
   local pathRoy
   if params.algo == 'knn' then
      if params.stage == 1 then
         local dir = string.format(
            'create-estimates-lua,algo=%s,obs=%s,radius=%s,which=laufer/',
            params.algo, params.obs, params.radius)
         local fileName = 'estimates-laufer.csv'
         pathRoy = dirAnalysis .. dir .. fileName
      elseif params.stage == 2 then
         local dir = 
            'incorporate-errors-lua,algo=knn,inRank=1,inTimeSgd=86400,obs=1A/'
         local fileName = 'estimates-stage2.csv'
         pathRoy = dirAnalysis .. dir .. fileName
      else
         error('logic', tostring(params.stage))
      end
   else
      error('logic', tostring(params.algo))
   end

   log:log(' ')
   log:log('files read')
   local function fr(name, value) log:log(' %11s = %s', name, value) end
   fr('pathLaufer', pathLaufer)
   fr('pathRoy', pathRoy)
   return pathLaufer, pathRoy
end

--------------------------------------------------------------------------------
-- splitApnDate
--------------------------------------------------------------------------------

function splitApnDate(apnDate)
   local trace = false
   assert(string.len(apnDate) == 18)
   local apn = string.sub(apnDate, 1, 10)
   local date = string.sub(apnDate, 11, 18)
   if trace then
      print('splitApnDate, both, apn, date',
            apnDate, apn, date)
   end
   return apn, date
end

--------------------------------------------------------------------------------
-- makeKey: return string with <apn>,<date>
--------------------------------------------------------------------------------

function makeKey(apn, date)
   --print('makeKey apn date', apn, date)
   return string.format('%10s,%8s', apn, date)
end

--------------------------------------------------------------------------------
-- createActualTable
--------------------------------------------------------------------------------

-- create table of log(actual) transaction prices
-- RETURN
-- actual     : table of actual transactions on actual dates
-- midQuarter : table of actual transactions moved to mid-quarter dates
function createActualTable(dirFeatures)
   local trace = false

   local function readCsv(filename)
      local path = dirFeatures .. filename
      return CsvUtils.read1Number(path)
   end

   local apns = readCsv('apns.csv')
   local dates = readCsv('date.csv')
   local logPrices = readCsv('SALE-AMOUNT-log.csv')
   
   assert(#apns == #dates)
   assert(#apns == #logPrices)

   local actual = {}
   local midQuarter = {}
   local countPrinted = 0
   for i = 1, #apns do
      local apn= apns[i]
      local date = dates[i]
      local logPrice = tonumber(logPrices[i])
      assert(string.len(apn) == 10, apn)
      assert(string.len(date) == 8, date)
      assert(logPrice)
      actual[apn .. date] = logPrice
      local midQuarterDate = nearestEstimatedDate(tonumber(date))
      midQuarter[apn .. midQuarterDate] = logPrice
      if countPrinted < 10 then
         print(string.format('actual date %s as moved to mid quarter %s',
                             date, midQuarterDate))
         countPrinted = countPrinted + 1
      end
      if trace then
         print('apn,date,midQuarterDate', apn, date, midQuarterDate)
      end
   end

   return actual, midQuarter
end --createActualTable

--------------------------------------------------------------------------------
-- createEstimatesTable
--------------------------------------------------------------------------------

-- ARGS:
-- name       : string, name of file, used in the log
-- format     : string, gmatch parse string returning apn,date,priceLog s.t.
--              apn, date, logPrice = string.gmatch(line,format)()
-- path       : string, path to input file
-- inputLimit : number, if > 0, only this many input records read 
--              used during testing
-- log        : Log instance
-- takeLog    : boolean
--              if true, the price is converted to log via math.log(price)
--              if false, the price is already in the log domain and is used
--                        without conversion
-- RETURNS:
-- transactions : table[apn..date] = logPrice
-- n            : number of transaction
-- set          : table[apn] = true, all APNs found
function createEstimatesTable(name, format, path, inputLimit, log, takeLog, 
                              specialApns)
   local trace = false
   assert(name)
   assert(format)
   assert(path)
   assert(inputLimit)
   assert(log)
   assert(takeLog ~= nil)
   assert(specialApns)

   log:log('\ncreating estimates table %s', name)
   log:log('path to input file = %s', path)
   log:log('inputLimit = %s', inputLimit)
   log:log('format = %s', format)

   local table = {}
   local set = {}
   local recordsUsed = 0
   
   -- read the CSV file directly using ARG format
   print(string.format('starting to read %s file: ', name))
   local file = io.open(path)
   if file == nil then
      error('unable to open estimates file; path = ' .. path)
   end
   local header = file:read()
   local countApns = 0
   local countTransactions = 0
   local countBadForm = 0
   for line in file:lines('*l') do
      local apn, date, priceString = string.gmatch(line, format)()
      local price = tonumber(priceString)
      if apn == nil or 
         string.len(apn) ~= 10 or 
         string.len(date) ~= 8 or 
         price == nil then
         log:log('skipping input line because of its form: %s', line)
         countBadForm = countBadForm + 1
      else
         if specialApns[apn] then
            print('found special apn,date,price',
                  apn, date, price)
         end
         if set[apn] == nil then
            countApns = countApns + 1
            set[apn] = true
         end
         if takeLog then
            table[apn .. date] = math.log(price)
         else
            table[apn .. date] = price
         end
         countTransactions = countTransactions + 1
      end
   end
   file:close()
   log:log('number of transactions created = %d', countTransactions)
   log:log('number of APNs read            = %d', countApns)
   log:log('number of input records skipped because of form = %d', 
           countBadForm)
   assert(countBadForm < 100) -- needs to be tuned
   return table, countTransactions, set, countApns
end --createEstimatesTable

--------------------------------------------------------------------------------
-- createLauferTable
--------------------------------------------------------------------------------


-- NOTE: Some lines in the Laufer file or miscoded in that the price is 
-- written as .ddddddd, an impossibly low value.
-- These records are detected and ignored
-- RETURNS
-- transations   : table[apn..date] == log price
-- nTransactions : number of transactions
-- apns          : table[apn] = true
-- nApns         : number of apns
function createLauferTable(path, inputLimit, log)
   assert(path)
   assert(inputLimit)
   assert(log)

   local inputRecordFormat = '(%d+),(%d+),(%d+[%.%d+]*)'
   local takeLog = true
   specialApns = {}
   specialApns['2615025006'] = true
   return createEstimatesTable('Laufer', 
                               inputRecordFormat, 
                               path, 
                               inputLimit, 
                               log,
                               takeLog,
                               specialApns)
end --readLauferTable

--------------------------------------------------------------------------------
-- createRoyTable
--------------------------------------------------------------------------------

-- RETURNS
-- transations   : table[apn..date] == log price
-- nTransactions : number of transactions
-- apns          : table[apn] = true
-- nApns         : number of apns
function createRoyTable(path, inputLimit, log)
   assert(path)
   assert(inputLimit)
   assert(log)

   local inputRecordFormat = '(%d+),(%d+),%d+,(%d+%.%d+)'
   local takeLog = false
   specialApns = {}
   return createEstimatesTable('Roy', 
                               inputRecordFormat, 
                               path, 
                               inputLimit, 
                               log,
                               takeLog,
                               specialApns)
end --readRoyTable

--------------------------------------------------------------------------------
-- printHeadSeq: print first few records of sequence
--------------------------------------------------------------------------------

function printHeadSequence(name, s)
   for i = 1, 10 do
      print(name, i, s[i])
   end
   if pause then continue() end
end --printHeadSequence

--------------------------------------------------------------------------------
-- printHeadTable: print first few records of table
--------------------------------------------------------------------------------

function printHeadTable(name, t)
   local count = 0
   for k, v in pairs(t) do
      print(name, k, v)
      count = count + 1
      if count == 10 then break end
   end
end --printHeadTable

--------------------------------------------------------------------------------
-- nearestEstimatedDate: mid-quarter date nearest the transaction date
--------------------------------------------------------------------------------

do
   local nearestMonth = {2, 2, 2, 5, 5, 5, 8, 8, 8, 11, 11, 11}

   function nearestEstimatedDate(date)
      assert(date)
      local year = math.floor(date / 10000)
      local month = math.floor((date - year * 10000) / 100)
      return tostring(year * 10000 + nearestMonth[month] * 100 + 15)
   end

   local function check(expected, actual)
      if expected == actual then 
         return
      else 
         print('expected', expected)
         print('actual', actual)
         halt()
      end
   end

   -- unit tests
   check('20020215', nearestEstimatedDate(20020101))
   check('20020215', nearestEstimatedDate(20020201))
   check('20020215', nearestEstimatedDate(20020301))

   check('20020515', nearestEstimatedDate(20020401))
   check('20020515', nearestEstimatedDate(20020501))
   check('20020515', nearestEstimatedDate(20020601))
   
   check('20010815', nearestEstimatedDate(20010701))
   check('20010815', nearestEstimatedDate(20010828))
   check('20010815', nearestEstimatedDate(20010930))

   check('20021115', nearestEstimatedDate(20021001))
   check('20021115', nearestEstimatedDate(20021101))
   check('20021115', nearestEstimatedDate(20021201))
end --nearestEstimatedDate

--------------------------------------------------------------------------------
-- compareApnSets
--------------------------------------------------------------------------------

-- which APNs are not common to both sets?
function compareApnSets(lauferApns, royApns, log)
   assert(lauferApns)
   assert(royApns)
   assert(log)

   local max = 20
   local function compare(base, other, baseName, otherName)
      log:log(' ')
      log:log('First %d APNs in %s that are not in %s',
              max, baseName, otherName)
      local missing = 0
      for apn, _ in pairs(base) do
         if other[k] == nil then
            missing = missing + 1
            if missing <= max then log:log(' %s', apn) end
         end
      end
      log:log('A total of %d APNs are in %s that are not in %s',
              missing, baseName, otherName)
   end

   -- return number of entries in table
   local function count(table) 
      local num = 0
      for k, v in pairs(table) do
         num = num + 1
      end
      return num
   end

   -- return number of common keys in tables
   local function common(table1, table2)
      local num = 0
      for k, v in pairs(table1) do
         if table2[k] ~= nil then
            num = num + 1
         end
      end
      return num
   end

   log:log('The HPI dataset has %d APNs', count(lauferApns))
   log:log('The other dataset has %d APNs', count(royApns))
   log:log('The number of common APNs in both is %d', 
           common(lauferApns, royApns))
   compare(lauferApns, royApns, 'Laufer', 'Roy')
   compare(royApns, lauferApns, 'Roy', 'Laufer')
end -- compareApnSets

--------------------------------------------------------------------------------
-- Tabulator
--------------------------------------------------------------------------------

do
   local Tabulator = torch.class('Tabulator')

   function Tabulator:__init()
      self.seen = 0
      
      -- how often each estimate is closer to the actual
      self.hpiCloser = 0
      self.otherCloser = 0
      self.equal = 0

      -- accumulators to calculate RMSEs
      self.hpiSumSquaredErrors = 0
      self.otherSumSquaredErrors = 0

      -- how often each estimate is within the limit
      self.limit = 0.10
      self.hpiWithinLimit = 0
      self.otherWithinLimit = 0
   end

   function Tabulator:tabulate(actualLog, hpiLog, otherLog)
      assert(actualLog)
      assert(hpiLog)
      assert(otherLog)
      
      self.seen = self.seen + 1
      
      -- how often each is closer to the estimate
      local absErrorHpi = math.abs(actualLog - hpiLog)
      local absErrorOther = math.abs(actualLog - otherLog)
      if absErrorHpi < absErrorOther then
         self.hpiCloser = self.hpiCloser + 1
      elseif absErrorHpi > absErrorOther then
         self.otherCloser = self.otherCloser + 1
      else
         self.equal = self.equal + 1
      end

      -- accumulate values needed to compute RMSEs
      self.hpiSumSquaredErrors = 
         self.hpiSumSquaredErrors + absErrorHpi * absErrorHpi
      self.otherSumSquaredErrors =
         self.otherSumSquaredErrors + absErrorOther * absErrorOther

      -- how often each within 10 percent (convert out of log domain)
      local actual = math.exp(actualLog)
      local hpi = math.exp(hpiLog)
      local other = math.exp(otherLog)

      if math.abs(actual - hpi) / actual < self.limit then
         self.hpiWithinLimit = self.hpiWithinLimit + 1
      end
      if math.abs(actual - other) / actual < self.limit then
         self.otherWithinLimit = self.otherWithinLimit + 1
      end
   end

   function Tabulator:report(log)
      log:log('Made %d comparisons', self.seen)

      log:log(' ')
      log:log('Hpi was closer in %d of these', self.hpiCloser)
      log:log('Other was closer in %d of these', self.otherCloser)
      log:log('Error was same in %d of these', self.equal)

      log:log(' ')
      log:log('RMSE for Hpi is %f', self:_rmse(self.hpiSumSquaredErrors))
      log:log('RMSE for other is %f', self:_rmse(self.otherSumSquaredErrors))

      log:log(' ')
      log:log('Fraction of estimates for which HPI was within %f: %f',
              self.limit, self.hpiWithinLimit / self.seen)
      log:log('Fraction of estimates for which other was within %f: %f',
              self.limit, self.otherWithinLimit / self.seen)
   end

   function Tabulator:_rmse(sumSquaredErrors)
      return math.sqrt(sumSquaredErrors / self.seen)
   end
end --class Tabulator

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
-- compareEstimates
--------------------------------------------------------------------------------

-- log entries that compare the two tables
-- input tables format: table[key] == logPrice
-- where key == a string of form apn .. date
function compareEstimates(hpiTable, otherTable, actualTable, log, which)
   local trace = true
   assert(hpiTable)
   assert(otherTable)
   assert(actualTable)
   assert(log)
   assert(which)

   log:log('Starting to compare estimates: %s', which)

   local countActualTransactions = 0
   local countNotIn200x = 0
   local countNotInHpi = 0
   local countNotInOther = 0
   local countNotInBoth = 0

   tabulator = Tabulator()
   for actualApnDate, actualLogPrice in pairs(actualTable) do
      assert(actualApnDate)
      assert(actualLogPrice)
      countActualTransactions = countActualTransactions + 1
      local apn, date = splitApnDate(actualApnDate)
      if trace and countActualTransactions < 20 then
         print(string.format('compareEstimates: actual apn %s date %s price %f',
                             apn, date, actualLogPrice))
      end
      if not in200x(date) then
         countNotIn200x = countNotIn200x + 1 
         if countNotIn200x < 11 then
            print('compareEstimates: not in 200x--', date)
         end
      else
         local approxApnDate = apn .. nearestEstimatedDate(date)
         local hpiLogPrice = hpiTable[approxApnDate]
         local otherLogPrice = otherTable[approxApnDate]
         if trace and false then
            print('compareEstimates: hpiLogPrice,otherLogPrice', 
                  hpiLogPrice, otherLogPrice)
         end
         
         if hpiLogPrice == nil and otherLogPrice ~= nil then
            countNotInHpi = countNotInHpi + 1
            
         elseif hpiLogPrice ~= nil and otherLogPrice == nil then
            countNotInOther = countNotInOther + 1
            
         elseif hpiLogPrice == nil and otherLogPrice == nil then
            -- in neither: print details
            countNotInBoth = countNotInBoth + 1
            if countNotInBoth < 11 then
               print('compareEstimates: approxApnDate', approxApnDate)
            end

         elseif hpiLogPrice ~= nil and otherLogPrice ~= nil then
            tabulator:tabulate(actualLogPrice, hpiLogPrice, otherLogPrice)
            
         else
            print('apn', apn)
            print('date', date)
            print('hpiLogPrice', hpiLogPrice)
            print('otherLogPrice', otherLogPrice)
            error('cannot be here')
         end
      end
   end
   
   log:log(' ')
   log:log('Saw %d actual transactions', countActualTransactions)
   log:log(' Of these, not in 2000, 2001, ..., 2009: %d', countNotIn200x)
   log:log(' Of these, in 200x and not in just HPI: %d', countNotInHpi)
   log:log(' Of these, in 200x and not in just Other: %d', countNotInOther)
   log:log(' Of these, in 200x and not in HPI nor Other: %d', countNotInBoth)
   log:log(' ')

   log:log('Comparison of accuracy')
   tabulator:report(log)
end -- compareEstimates

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

-- setup and log paths to the two input files
local pathLaufer, pathRoy = setupInputPaths(dirAnalysis, log, params)

if params.limitEstimates > 0 then
   log:log('INPUT FILES NOT ENTIRELY READ')
   log:log('params.limitEstimates = %d', params.limitEstimates)
end

-- read the actuals into table of same format
local actualTable, redatedActualTable = createActualTable(dirFeatures)
printHeadTable('Head of actual prices table', actualTable)
printHeadTable('head of redated actual prices table', redatedActualTable)

-- read the two table of estimates
local lauferTable, transactions, lauferApnSet, apns = 
   createLauferTable(pathLaufer, params.limitEstimates, log)
printHeadTable('Head of laufer table', lauferTable)
specialApn = '2615025006'
if lauferApnSet[specialApn] then
   print('Laufer APN table contains', specialApn)
else
   print('Laufer APN table does not contain', specialApn)
   halt()
end
if apnInTable(specialApn, lauferTable) then
   print('Laufer Table contains', specialApn)
else
   print('Laufer table does not contain', specialApn)
end

print('special apn in Laufer table', specialApn)

local royTable, _, royApnSet = 
   createRoyTable(pathRoy, params.limitEstimates, log)
printHeadTable('Head of roy table', royTable)

-- compare Apn sets
compareApnSets(lauferApnSet, royApnSet, log)

-- compare the estimates
log:log('\nCOMPARING TO ACTUAL TRANSACTION')
compareEstimates(lauferTable, 
                 royTable, 
                 actualTable, 
                 log, 
                 'actual transactions on actual dates')

log:log('\nCOMPARING TO REDATED TRANSACTIONS')
compareEstimates(lauferTable, 
                 royTable, 
                 redatedActualTable, 
                 log, 
                 'actual transactions on mid-quarter dates')

printParams(params, log)

log:log(' ')
log:log('finished')

log:close()



