-- keys.lua

-- determine keys in a table
-- ARGS
-- t : table
--
-- RETURNS
-- seq: a sequence containing each key in table t
function keys(t)
   assert(type(t) == 'table')
   local result = {}
   for k in pairs(t) do
      table.insert(result, k)
   end
   return result
end