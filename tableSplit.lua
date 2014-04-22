-- tableSplit.lua
-- arbitrarily spit a table into two subtables
function tableSplit(t)
   local t1 = {}
   local t2 = {}
   local which = 1
   for k, v in pairs(t) do
      if which == 1 then
         t1[k] = v
         which = 2
      else
         t2[k] = v
         which = 1
      end
   end
   return t1, t2
end
