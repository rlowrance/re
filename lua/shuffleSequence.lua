-- shuffle.lua
-- shuffle elements of a sequence

require 'makeVerbose'

-- ref:
-- http://developer.coronalabs.com/forum/2011/03/23/shuffling-table-values

-- return randomly shuffled version of s
-- do not mutate s
function shuffleSequence(s)
   local v = makeVerbose(false, 'shuffleSequence')

   assert(s)
   assert(type(s) == 'table', 's must be a table that is a sequence')

   local t = {}
   for i = 1, #s  do
      t[i] = s[i]
   end

   local rand = math.random
   for i = #s, 2, -1 do
      j = rand(i)  -- j in [1,i]
      v('i,j', i, j)
      t[i], t[j] = t[j], t[i]
      v('t after swapping i and j', t)
   end

   return t
end