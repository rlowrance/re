-- sortedKeys.lua
-- return the sequence of sorted keys from a table
function sortedKeys(t)
   assert(t)
   local keys = {}
   for key in pairs(t) do
      keys[#keys + 1] = key
   end
   table.sort(keys)
   return keys
end