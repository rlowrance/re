-- tableCopy.lua
-- return a deep copy of a table, but don't make a fresh instance of userdata
function tableCopy(t)
   local new = {}
   for k, v in pairs(t) do
      if type(k) == 'table' then
         k = tableCopy(k)
      end
      if type(v) == 'table' then
         v = tableCopy(v)
      end
      new[k] = v
   end
   return new
end
