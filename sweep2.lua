-- sweep2.lua

-- sweep a function over 2 parameter sequences
-- ARGS:
-- fn: function of two arguments
-- seq1: a sequence
-- seq2: a sequence
-- RETURNS: a result table such that result[e1][e2] = fn(e1, e2)
function sweep2(fn, seq1, seq2)
   local result = {}
   for _, e1 in ipairs(seq1) do
      for _, e2 in ipairs(seq2) do
         local r = fn(e1, e2)
         if result[e1] == nil then
            result[e1] = {}
         end
         result[e1][e2] = r
      end
   end
   print('result', result)
   return result
end
