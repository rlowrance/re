-- sweep1.lua

-- sweep a function of 1 parameter across a sequence
-- ARGS
-- fn: function of one argument, an element of the sequence
-- seq1: sequence
-- RETURNS: a table with 
--  key = an element of seq1
--  value = fn(key)
function sweep1(fn, seq1)
   local result = {}
   for _, e1 in ipairs(seq1) do
      result[e1] = fn(e1)  -- holds multiple values, if fn returns them
   end
   return result
end