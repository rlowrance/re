-- keyWithMinimumValue.lua

-- return key in table with the minimum value
-- ARGS
-- table : a table
-- RETURNS:
-- key   : key in table with minimum value, potentially nil
function keyWithMinimumValue(table)
   local minValueSeen = math.huge
   local minKeySeen = nil
   for k, v in pairs(table) do
      if v < minValueSeen then
         minKeySeen = k
         minValueSeen = v
      end
   end
   return minKeySeen
end
