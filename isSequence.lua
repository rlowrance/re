-- isSequence.lua

require 'makeVp'

-- return true iff the obj is a sequence (NOTE: EXPENSIVE)
-- A sequence has only numeric keys in {1, 2, ..., n} for some n
-- It may have non-numeric keys and still be a sequence
function isSequence(obj)
   local vp = makeVp(0, 'isSequence')
   vp(1, 'obj', obj)
   if type(obj) ~= 'table' then
      return false
   end

   local numericKeys = {}
   local n = 0
   for k, v in pairs(obj) do
      if type(k) == 'number' then
         numericKeys[k] = true
         n = n + 1
      else
         return false
      end
   end

   vp(2, 'n', n, 'numericKeys', numericKeys)
   for i = 1, n do
      if not numericKeys[i] then
         return false
      end
   end

   return true
end