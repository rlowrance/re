-- tableMerge.lua
-- return new table containing all k,v pairs from two tables
function tableMerge(t1, t2)
   local result = {}
   for k, v in pairs(t1) do
      result[k] = v
   end
   for k, v in pairs(t2) do
      result[k] = v
   end
   return result
end
