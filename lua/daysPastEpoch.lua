-- daysPastEpoch.lua
-- define function return number of days past an epoch (1900-01-01)
-- The old epoch date is needed because some transactions date to 1908
-- and I don't want to use negative day numbers (as uncertain what the
-- effect would be).

do
   local daysPerMonth = 
      {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
   
   local function isLeapYear(year)
      if (year % 100) == 0 then
         if (year % 400)  == 0 then
            return 0
         else
            return 1
         end
      elseif  (year % 4) == 0 then 
         return 1 
      else 
         return 0 
      end
   end

   local firstYear = 1900
   
   function daysPastEpoch(date)
      local trace = false
      local year  = math.floor(date / 10000)
      local month = math.floor(date / 100 - year * 100)
      local day   = math.floor(date - year * 10000 - month * 100)
      if trace then print(date, year, month, day) end
      
      -- new version
      assert(year >= firstYear)
      
      local yearDays = 0
      for yearNumber = firstYear, year - 1 do
         yearDays = yearDays + 365 + isLeapYear(yearNumber)
      end
      
      local monthDays = 0
      for monthNumber = 1, month - 1 do
         monthDays = monthDays + daysPerMonth[monthNumber]
      end
      
      local leapDay = 0
      if isLeapYear(year) and month > 2 then
         leapDay = 1
      end
      
      local result = yearDays + monthDays + leapDay + day - 1
      if trace then print(yearDays, monthDays, leapDay, result) end
      
      return result
   end
end