-- tableFold.lua
-- ARGS
-- table : table
-- f     : function(k, v, type(init)) --> type(init)
-- init  : initial value
function tableFold(table, f, init)
   local result = init
   for k, v in pairs(table) do
      result = f(k, v, result)
   end
   return result
end
