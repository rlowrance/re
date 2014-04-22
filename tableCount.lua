-- tableCount.lua
-- return number of entries in a table
function tableCount(t)
   local count = 0
   for k, v in pairs(t) do
      count = count + 1
   end
   return count
end
