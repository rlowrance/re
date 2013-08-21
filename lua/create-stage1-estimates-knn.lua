-- create-stage1-estimates-knn.lua
-- estimate the value of each APN for each month in 2000 .. 2009

require 'all'

--------------------------------------------------------------------------------
-- FUNCTIONS
--------------------------------------------------------------------------------

function date(year, month, day)
   return year * 10000 + month * 100 + day
end

function replaceDate(query, date, columnNumber, sd)
   -- determine the standardized day number for the year and month and day
   -- mutate the query by putting it in the specified column
   -- ARGS:
   -- query : 1D Tensor
   -- date  : integer > 0 as YYYYMMDD
   -- sd    : StandardizedDate instance
   
   local v = makeVerbose(false, 'replaceDate')

   affirm.isTensor1D(query, 'query')
   affirm.isIntegerPositive(date, 'date')
   affirm.isIntegerPositive(columnNumber, 'columnNumber')
   affirm.isTable(sd, 'sd')

   local stdDay = sd:standardized(date)
   v('date, stdDay', date, stdDay)

   query[columnNumber] = stdDay
end -- replaceDate

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

print('***********************************************************************')

local v = makeVerbose(true, 'main')

local options, dirResults, log, dirOutput = 
   parseOptions(arg, 
                'create estimate for each transaction in each month',
                {{'-dataDir', '../../data/', 'path to data directory'},
                 {'-k',  15, 'GUESS: optimal value of k'},
                 {'-obs', '', 'observation set'},
                 {'-seed', 27, 'random number seed'},
                 {'-test', 1, '0 for production, 1 to test'}})

   log:log('STUB: add correction optimal value for k')

-- validate options
assert(options.obs == '1A' or options.obs == '2R',
      'invalid options.obs')
assert(options.test == 0 or options.test == 1,
      'invalid options.test')

if options.test == 1 then
   log:log('TESTING')
end

if true then
   setRandomSeeds(options.seed)
else
   log:log('STUB: random number seeds not set to known value')
end

local function inputLimit(options)
   if options.test == 0 
   then return 0
   else return 1000
   end
end -- inputLimit

-- read the training data
local nObservations, trainingData = readTrainingData(options.dataDir,
                                                     log, 
                                                     inputLimit(options), 
                                                     options.obs)

local nColumnStandardizedDay = standardizedDayColumn(options.dataDir,
                                                     options.obs)

local sd = StandardizeDate(options.dataDir, options.obs)

-- Do the work
local outFilename = string.format('estimates-stage1-knn-%s.csv',
                                  options.obs)
local out, err = io.open(dirOutput .. outFilename, 'w')
if out == nil then
   error('unable to open output file; err = ' .. err)
end
out:write('apn,date,price\n')

local knn = Knn(options.k + 1)
local tc = TimerCpu()
local countOk = 0
local apnsSeen = Set()    -- estimate each APN exactly once
for i = 1, nObservations do
   local apn = trainingData.apns[i]
   if not apnsSeen:hasElement(apn) then
      apnsSeen:add(apn)
      v('apn was not previously seen:', apn)
      for year = 2000, 2009 do
         for month = 1, 12 do
            local query = trainingData.features[i]:clone()
            -- replace day-std in query with new value
            --v('query', query)
            local dateForEstimate = date(year, month, 15)
            replaceDate(query, dateForEstimate, nColumnStandardizedDay, sd)
            --v('updated query', query)
            collectgarbage()
            local ok, estimate = knn:estimate(trainingData.features,
                                              trainingData.prices,
                                              query,
                                              options.k)
            --v('ok,estimate', ok, estimate)
            if ok then
               countOk = countOk + 1
               line = string.format('%d,%8d,%0.2f', 
                                    apn, 
                                    dateForEstimate, 
                                    estimate)
               out:write(line .. '\n')
            else
               error('not ok; reason = ' .. estimate)
            end
         end -- month loop
      end -- year loop
      if i % 1000 == 0 then
         local nApnsEstimated = apnsSeen:nElements()
         log:log('%d of %d; APNs seen %d; countOk %d; cpuSec per APN %f',
                 i, 
                 nObservations, 
                 nApnsEstimated, 
                 countOk, 
                 tc:cumSeconds() / nApnsEstimated)
      end
      if options.test == 1 and i > 100 then
         log:log('TESTING: TRUNCATED OUTPUT')
         break
      end
   end -- if to select unseen APN
end -- observation loop

out:close()
log:log('read %d transaction data records', nObservations)
log:log('estimated %d APNs', apnsSeen:nElements())
log:log('wrote %d data records containing estimates', countOk)



-- Wrap up
printOptions(options, log)

if options.test == 1 then
   log:log('TESTING')
end

log:log('consider comiting the code')
