-- create-transactions.lua

require 'csvutils'

--------------------------------------------------------------------------------
-- read command line
--------------------------------------------------------------------------------

cmd = torch.CmdLine()
cmd:text("Create file transactions.csv in activities directory" .. 
	 " containing apns,date,months,days,prices")
cmd:text()
cmd:text('Run from lau directory')
cmd:text()
cmd:text('Options')
cmd:option('-dataDir','','Path to data directory')
cmd:option('-obs','','Observation set')

-- parse command line
params = cmd:parse(arg)

-- check for missing required command line parameters
function missing(name)
   error('missing parameter -' .. name)
end

if params.dataDir == '' then missing('dataDir') end
if params.obs == '' then missing('obs') end

--------------------------------------------------------------------------------
-- establish directories
--------------------------------------------------------------------------------

dirObs = params.dataDir .. 'generated-v4/obs' .. params.obs .. '/'
dirFeatures =  dirObs .. 'features/'
dirAnalysis =  dirObs .. 'analysis/'

--------------------------------------------------------------------------------
-- start logging
--------------------------------------------------------------------------------

dirLog = 
   dirAnalysis ..  
   cmd:string('create-transactions', 
	      params, 
	      {dataDir = true}) .. 
   '/'
print('dirLog', dirLog)
os.execute('mkdir ' .. dirLog)  -- create directory if it does not exist

pathLogFile = dirLog .. 'log.txt'
print('pathLogFile', pathLogFile)
cmd:log(pathLogFile, params) -- also prints command line

print()
print('dirAnalysis', dirAnalysis)
print('dirFeatures', dirFeatures)
print('dirObs', dirObs)

--------------------------------------------------------------------------------
-- read all the input files into arrays
--------------------------------------------------------------------------------

apns = CsvUtils.read1Number(dirFeatures .. 'apns.csv')
dates = CsvUtils.read1Number(dirFeatures .. 'date.csv')
prices = CsvUtils.read1Number(dirFeatures .. 'SALE-AMOUNT.csv')

assert(#apns == #dates)
assert(#apns == #prices)

--------------------------------------------------------------------------------
-- create the years, months, days arrays
--------------------------------------------------------------------------------

years = {}
months = {}
days = {}

for i=1,#dates do
   local date = dates[i]
   local year = math.floor(date / 10000)
   local month = math.floor((date - year * 10000) / 100)
   local day = date - year * 10000 - month * 100
   years[#years + 1] = year
   months[#months + 1] = month
   days[#days + 1] = day
end

--------------------------------------------------------------------------------
-- write the transactions.csv file
--------------------------------------------------------------------------------

transactionsFilePath = dirFeatures .. 'transactions.csv'
transactionsFile = io.open(transactionsFilePath, 'w')

-- write header
transactionsFile:write('apn,year,month,day,price')
transactionsFile:write('\n')

-- write each data line
-- Q: covert to strings first? this assumes not
for i=1,#dates do
   transactionsFile:write(string.format('%d,%d,%d,%d,%d\n',
					apns[i],
					years[i],
					months[i],
					days[i],
					prices[i]))
end

transactionsFile:close()

print()
print(string.format('Wrote %d data records\nto file %s',
		    #dates, transactionsFilePath))

   