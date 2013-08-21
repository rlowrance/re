-- create-estimates-knn.lua

require 'CsvUtils'
require 'Knn'

--------------------------------------------------------------------------------
-- read command line, setup directories, and start logging
--------------------------------------------------------------------------------

do
   local cmd = torch.CmdLine()
   cmd:text('Create estimates for knn algorithm')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-dataDir', '../../data/', 'Path to data directory')
   cmd:option('-k',0,'Number of neighbors') -- k == 24 is optimal for 1A
   cmd:option('-obs','', 'Observation set')
   cmd:option('-test','no','If supplied, use only a few features')
   cmd:option('-which','transactions','Set to "all" to generate all prices')
   params = cmd:parse(arg)
   
   function printParams()
      print()
      print('Command line arguments')
      for k,v in pairs(params) do
	 print(string.format('%10s %q', k, v))
      end
   end

   printParams()

   -- check for missing parameters
   function missing(name) error('missing parameter - ' .. name) end
   if params.k == 0 then missing('k') end
   if params.obs == '' then missing('obs') end

   dirObs = params.dataDir .. 'generated-v4/obs' .. params.obs .. '/'
   dirAnalysis = dirObs .. 'analysis/'
   dirFeatures = dirObs .. 'features/'

    -- start logging
   dirResults = 
      dirAnalysis .. cmd:string('create-estimates-knn', params, {}) .. '/'
   print('dirResults', dirResults)
   os.execute('mkdir ' .. dirResults)
   cmd:log(dirResults .. 'log.txt', params)
end

--------------------------------------------------------------------------------
-- define function to break a date into year and month
--------------------------------------------------------------------------------

function dateToYear(date)
   return math.floor(date / 10000)
end

function dateToYearMonth(date)
   local year = dateToYear(date)
   local month = math.floor(date / 100 - year * 100)
   return year, month
end



--------------------------------------------------------------------------------
-- define functions to read or synthesize data
--------------------------------------------------------------------------------

-- return an array of numbers read from a CSV file with one column
function read(fileBaseName)
   print('reading ' .. fileBaseName)
   return CsvUtils.read1Number(dirFeatures .. fileBaseName .. '.csv')
end

-- return apns, dates, features, dateToStdDaysFunction
-- + apns: array of numbers
-- + dates: array of numbers
-- + features: 2D tensor
-- + dateToDaysFunction(year,month,day)-->day number standardized
function read1A()
   local apns = read('apns')
   local dates = read('date')
   local days = read('day')
   local prices = read('SALE-AMOUNT-log')
   --local dayStds = read('day-std')
   
   local numObservations = #apns
   local numFeatures = 62
   print('read1A numObservations', numObservations)
   local features = torch.Tensor(numObservations, numFeatures)
   
   local column = 0
   local function set(fileBaseName) -- set next column to file content
      local array = read(fileBaseName)
      assert(#array == numObservations, '#array=' .. #array)
      column = column + 1
      --print('column', column)
      for i=1,numObservations do
	 features[i][column] = array[i]
      end
   end
   
   -- read each feature and set as part of the features 2D tensor
   set('day-std')
   set('BEDROOMS-std')
   set('census-avg-commute-std')
   set('census-ownership-std')
   set('latitude-std')
   set('longitude-std')
   if params.test == 'no' then
      set('PARKING-SPACES-std')
      set('TOTAL-BATHS-CALCULATED-std')
      set('ACRES-log-std')
      set('census-income-log-std')
      set('YEAR-BUILT-std')
      set('IMPROVEMENT-VALUE-CALCULATED-log-std')
      set('LAND-VALUE-CALCULATED-log-std')
      set('LIVING-SQUARE-FEET-log-std')
      -- use all  of the codes for foundation and similar coded values
      set('FOUNDATION-CODE-is-001')
      set('FOUNDATION-CODE-is-CRE')
      set('FOUNDATION-CODE-is-MSN')
      set('FOUNDATION-CODE-is-PIR')
      set('FOUNDATION-CODE-is-RAS')
      set('FOUNDATION-CODE-is-UCR')
      set('percent-improvement-value-std')
      set('FOUNDATION-CODE-is-SLB')
      set('HEATING-CODE-is-00S')
      set('HEATING-CODE-is-001')
      set('HEATING-CODE-is-BBE')
      set('HEATING-CODE-is-CL0')
      set('HEATING-CODE-is-FA0')
      set('HEATING-CODE-is-FF0')
      set('HEATING-CODE-is-HP0')
      set('HEATING-CODE-is-HW0')
      set('HEATING-CODE-is-SP0')
      set('HEATING-CODE-is-ST0')
      set('HEATING-CODE-is-GR0')
      set('HEATING-CODE-is-RD0')
      set('HEATING-CODE-is-SV0')
      set('HEATING-CODE-is-WF0')
      set('LOCATION-INFLUENCE-CODE-is-I01')
      set('LOCATION-INFLUENCE-CODE-is-IBF')
      set('LOCATION-INFLUENCE-CODE-is-ICA')
      set('LOCATION-INFLUENCE-CODE-is-ICR')
      set('LOCATION-INFLUENCE-CODE-is-ICU')
      set('LOCATION-INFLUENCE-CODE-is-IGC')
      set('LOCATION-INFLUENCE-CODE-is-ILP')
      set('LOCATION-INFLUENCE-CODE-is-IRI')
      set('LOCATION-INFLUENCE-CODE-is-IWL')
      set('PARKING-TYPE-CODE-is-110')
      set('PARKING-TYPE-CODE-is-120')
      set('PARKING-TYPE-CODE-is-140')
      set('PARKING-TYPE-CODE-is-450')
      set('PARKING-TYPE-CODE-is-920')
      set('PARKING-TYPE-CODE-is-A00')
      set('PARKING-TYPE-CODE-is-ASP')
      set('PARKING-TYPE-CODE-is-OSP')
      set('PARKING-TYPE-CODE-is-PAP')
      set('PARKING-TYPE-CODE-is-Z00')
      set('POOL-FLAG-is-0')
      set('POOL-FLAG-is-1')
      set('ROOF-TYPE-CODE-is-F00')
      set('ROOF-TYPE-CODE-is-G00')
      set('ROOF-TYPE-CODE-is-I00')
      set('TRANSACTION-TYPE-CODE-is-1')
      set('TRANSACTION-TYPE-CODE-is-3')   
   end
   print('column', column)
   print('numFeatures', numFeatures)
   print('params.test', params.test)
   assert(params.test == 'yes' or column == numFeatures)

   -- return a standardized number of days past some epoch
   local daysTensor = torch.Tensor(days)
   local meanDay = torch.mean(daysTensor)
   local stdDay = torch.std(daysTensor)
   print('Read1A meanDay stdDay', meanDay, stdDay)
   -- the epoch starts 1979-1-1 at midnight
   local epochSeconds = os.time{year=1979,month=1,day=1,hour=0}
   local secondsPerDay = 24 * 60 * 60

   local function dateToDay(theYear, theMonth, theDay)
      return (os.time{year=theYear,month=theMonth,day=theDay,hour=0} -
	      epochSeconds) / secondsPerDay
   end

   local function dateToDayStd(theYear, theMonth, theDay)
      local daysPastEpoch = dateToDay(theYear,theMonth,theDay)
      local result = (daysPastEpoch - meanDay) / stdDay
      -- print('dateToDayStd', theYear, theMonth, theDay, result)
      return result
   end

   -- test dateToStd
   assert(0 == dateToDay(1979, 1, 1))
   assert(dateToDayStd(1979,1,1) < 0)

   return apns, dates, features, prices, dateToDayStd
end

-- generate random test observations (not presently used)
function createTestData(numObservations, numFeatures)
   print('Generating random test observations')
   print('numObservations', numObservations)
   print('numFeatures', numFeatures)


   local apns = {}
   local dates = {}
   local days = {}
   local features = torch.Tensor(numObservations, numFeatures)
   local prices = {}

   local setFeatures = function(i)
      for k=1,numFeatures do
	 features[i][k] = math.random() -- uniform pseudo-random in [0,1)
      end
   end

   for i=1,numObservations do
      apns[#apns+1] = 1234567890 + i - 1
      dates[#dates+1] = 20000100 + i
      days[#days] = i  -- the epoch is 2000-01-00
      prices[#prices+1] = 100
      setFeatures(i)
   end

   local meanDay = torch.mean(torch.Tensor(days))
   local stddevDay = torch.std(torch.Tensor(days))
   
   local function dateToDayStd(year, month, day)
      local daysPathEpoch = (year - 2000) * 365 + month * 30 + day
      local result = (daysPastEpoch - meanDay) / stddevDay
      return result
   end

   return apns, dates, features, torch.Tensor(prices), dateToDayStd
end

--------------------------------------------------------------------------------
-- read the apns, dates, and features
--------------------------------------------------------------------------------

if params.obs == '1A' then
   apns, dates, features, prices, dateToDayStd = read1A()
else
   print('params.obs invalid or not implemented', params.obs)
end

--------------------------------------------------------------------------------
-- define how to estimate values
-- write csv file with columns apn,date,k,estimate
--------------------------------------------------------------------------------


-- return iterator over rows of a 2D tensor
function iteratorTensor(tensor, i)
   i = i + 1
   if i > tensor:size(1) then 
      return nil 
   else 
      return i, tensor[i]
   end
   return iter, tensor, 0
end

-- mimic pairs(table)
function pairsTensor(tensor)
   return iteratorTensor, tensor, 0
end


-- return number of month nearest to the transaction month
function makeNearestMonth(transactionMonth)
   if transactionMonth == 1 or 
      transactionMonth == 2 or 
      transactionMonth == 3 then 
      return 2 
   elseif 
      transactionMonth == 4 or
      transactionMonth == 5 or
      transactionMonth == 6 then 
      return 5 
   elseif 
      transactionMonth == 7 or
      transactionMonth == 8 or
      transactionMonth == 9 then 
      return 8
   else 
      return 11
   end
end

-- create a query by standardizing the day number
-- interpolate from known dates
-- the first feature is the day-std value
-- + features: 1D tensor, first element is days past epoch, standardized
function makeQuery(features, year, month, day)
   local daysStd = dateToDayStd(year, month, day)
   local result = features:clone()
   result[1] = daysStd
   return result
end

csvFileName = dirResults .. 'estimates.csv'
csvFile = io.open(csvFileName, 'w')
csvFile:write('apn,date,k,estimate\n')

function writeCsv(i,apn, date, k, estimate)
   local line = string.format('%d,%d,%d,%.2f', apn, date, k, estimate)
   print('writeCsv', i, line)
   csvFile:write(line .. '\n')
end

function makeDate(year,month,day)
   return string.format('%4d%02d%02d', year, month, day)
end

-- estimate values only for transactions that actually occur in 2000-2009
-- write estimates using function writeCsv
function estimateTransactions(k, apns, dates, features, writeCsv)
   for i=1,#apns do
      local knn = Knn()
      local date = dates[i]
      local year, month = dateToYearMonth(date)
      -- print('estimateTransactions', date, year, month)
      if 2000 <= year and year <= 2009 then
	 local nearestMonth = makeNearestMonth(month)
	 -- print('estimateTransactions nearestMonth', nearestMonth)
	 local estimate = knn:regressNew(features,
					 pairsTensor,
					 prices,
					 k,
					 makeQuery(features[i],
						   year, 
						   nearestMonth, 
						   15),
					 torch.dist)
	 writeCsv(i,
		  apns[i],
		  makeDate(year,nearestMonth,15),
		  k,
		  math.exp(estimate))
      end
   end
end

--------------------------------------------------------------------------------
-- create the estimates and write to CSV file
--------------------------------------------------------------------------------


if params.which == 'all' then
   estimateAll(params.k, apns, dates, features, writeCsv)
else
   estimateTransactions(params.k, apns, dates, features, writeCsv)
end

csvFile:close()