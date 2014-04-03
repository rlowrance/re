-- setUnion.lua
-- return union of two sets
-- ARGS
-- set1  : table s.t. table[key] = true iff element key is in the set
-- set2  : table
-- RETURNS
-- result : table
function setUnion(set1, set2)
   local result = {}
   for key, value in pairs(set1) do
      if value then
         result[key] = true
      end
   end

   for key, value in pairs(set2) do
      if value then
         result[key] = true
      end
   end

   return result
end
