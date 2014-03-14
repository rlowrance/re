--tableFilter.lua
--return new table containing just elements that satisfy a predicate
function tableFilter(table, predicate)
   local result = {}
   for k, v in pairs(table) do
      if predicate(k,v) then
         result[k] = v
      end
   end
   return result
end
