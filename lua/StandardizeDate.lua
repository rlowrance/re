-- StandardizeDate.lua
-- class to convert dates (yyyymmdd) to standardized day numbers

-- API overview
if false then
   sd = StandardizeDate(dataDir, obs)

   standardizedDate = sd:standardized(date)
end

require 'affirm'
require 'CsvUtils'
require 'makeVerbose'

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('StandardizeDate')

function StandardizeDate:__init(dataDir, obs)
   local v = makeVerbose(false, 'StandardizeDates:__init')
   affirm.isString(dataDir, 'dataDir')
   affirm.isString(obs, 'obs')
   assert(obs == '1A' or obs == '2R',
          'obs must be 1A or 2R')

   -- read first few records of each kind of date
   self.dates = self:_read(dataDir, obs, 'dates')
   self.days = self:_read(dataDir, obs, 'days')
   self.daysStd = self:_read(dataDir, obs, 'days-std')

   v('dates', self.dates)
   v('days', self.days)
   v('daysStd', self.daysStd)

   -- verify that the epoch is really as stated below
   self.epoch = 19700101  -- this date was set a long time ago in the java code
   for i = 1, self.dates:size(1) do
      v('date,days,computed', 
        self.dates[i], self.days[i], self:_daysPastEpoch(self.dates[i]))
      assert(self.days[i], self:_daysPastEpoch(self.dates[i]))
   end

   -- determine the mean and standard deviation of all the dates
   self.mu, self.sigma = self:_getMuSigma(self.days[1], self.daysStd[1],
                                          self.days[2], self.daysStd[2])
   assert(self.sigma ~= 0)

   -- check mu and sigma against existing entries
   for i = 1, self.dates:size(1) do
      local supposedDayStd = self:standardized(self.dates[i])
      v('recalculated dayStd, file dayStd', supposedDayStd, self.daysStd[i])
      assert(math.abs(supposedDayStd - self.daysStd[i]) < 1e-10)
   end
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
--------------------------------------------------------------------------------

function StandardizeDate:standardized(date)
   -- return standardized day number
   affirm.isIntegerPositive(date, 'date')
   return (self:_daysPastEpoch(date) - self.mu) / self.sigma
end -- standardize

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

function StandardizeDate:_components(date)
   -- return table containing year, month, day, hour = 0
   local v = makeVerbose(false, 'StandardizeDate:_components')
   v('date', date)
   local year = math.floor(date / 10000)
   local month = math.floor(date / 100 - year * 100)
   local day = date - year *10000 - month * 100
   local hour = 0
   v('date,year,month,day', date, year, month, day)
   return {year=year, month=month, day=day, hour=hour}
end -- _components

function StandardizeDate:_daysPastEpoch(date)
   local v = makeVerbose(false, 'StandardizeDate:_daysPastEpoch')
   local epochSecs = os.time(self:_components(self.epoch))
   local dateSecs = os.time(self:_components(date))
   v('epochSecs', epochSecs)
   v('dateSecs', dateSecs)
   local elapsedSecs = dateSecs - epochSecs
   -- round to nearest integer
   local elapsedDays = math.floor(elapsedSecs / (24 * 60 * 60) + 0.5)
   v('date', date)
   v('epochSecs,dateSecs,elapsedDays', epochSecs, dateSecs, elapsedDays)
   return elapsedDays
end -- _daysPastEpoch

function StandardizeDate:_getDays()
   return self.days
end -- _getDays

function StandardizeDate:_getDaysStd()
   return self.daysStd
end -- _getDaysStd


function StandardizeDate:_getMuSigma(day1, daystd1, day2, daystd2)
   local v = makeVerbose(false, 'StandardizeDate:_getMuSigma')
   assert(daystd1 ~= 0)
   assert(daystd1 ~= daystd2)
   local mu = (daystd1 * day2 - daystd2 * day1) / (daystd1 - daystd2)
   local sigma = (day1 - mu) / daystd1
   v('mu,sigma', mu, sigma)
   return mu, sigma
end

function StandardizeDate:_read(dataDir, obs, name)
   -- return first 100 records
   local cu = CsvUtils()
   local filename = 'obs' .. obs .. '-all-' .. name .. '.csv'
   local inPath = dataDir .. 'v5/inputs/' .. filename
   local inputLimit = 100
   local data, header = cu:read1Number(inPath,
                                       true, -- has a header
                                       '1D Tensor',  -- return a Tensor
                                       inputLimit)
   return data
end -- _read
                                       
   