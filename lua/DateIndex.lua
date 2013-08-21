-- DateIndex.lua
-- associate dates with sequence index numbers

require 'assertEqual'

--------------------------------------------------------------------------------
-- DateIndex
--------------------------------------------------------------------------------

-- class to convert dates to and from colum indices
torch.class('DateIndex')

--------------------------------------------------------------------------------
-- __init
--------------------------------------------------------------------------------
   
function DateIndex:__init(period, firstYear)
   assert(period)
   assert(firstYear)
   self.period = period
   self.firstYear = firstYear
   self.date2IndexTable = {}
   self:_makeDate2IndexTable(period, firstYear)
end

--------------------------------------------------------------------------------
-- date2Index
--------------------------------------------------------------------------------

function DateIndex:date2Index(date)
   assert(type(date) == 'string')
   assert(string.len(date) == 8)
   local result = self.date2IndexTable[self:_normalize(date)]
   assert(result, date)
   return result
end

--------------------------------------------------------------------------------
-- index2Date
--------------------------------------------------------------------------------

function DateIndex:index2Date(index)
   assert(type(index) == 'number')
   assert(index > 0)
   if self.index2DateTable == nil then self:_makeIndex2DateTable() end
   local result = self.index2DateTable[index]
   assert(result, index)
   return result
end

--------------------------------------------------------------------------------
-- _makeDate2IndexTable
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- _makeIndex2DateTable
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- UNIT TEST
--------------------------------------------------------------------------------

-- unit test of methods date2Index and index2Date
do 
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
