-- tableCopy.lua
-- return a deep copy of a table, except for userdata
function tableCopy(t)
   local new = {}
   for k, v in pairs(t) do
      if type(v) == 'table' then
         new[k] = tableCopy(v)
      else
         new[k] = v
      end
   end
   return new
end
