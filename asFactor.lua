-- asFactor.lua

require 'ifelse'
require 'makeVp'

-- convert sequence on {string, NA} to a factor (as in R)
-- 
-- ARGS:
-- seq : sequence on {string, Dataframe.NA (a table)}
--       the values to be converted
-- NA  : object that is not a string
--       the value that designates a missing value
--
-- Return two values such that 
--   seq[i]     == levels[indices[i]]       , if seq[i] is not NA
--   indices[i] == NA                       , if seq[i] is NA
-- indices : sequence on {integer, Dataframe.NA}
-- levels  : sequence on {string}
function asFactor(seq, NA)
   local vp = makeVp(0, 'asFactor')
   vp(1, 'seq', seq, 'NA', NA)
   assert(type(seq) == 'table')
   assert(type(NA) == 'table')

   -- build the indices
   -- as a side effect, build table levelsOf
   local indices = {}
   local nextIndex = 0
   local levelOf = {}
   for i, element in ipairs(seq) do
      vp(2, 'i', i, 'element', element)
      if element == NA then
         indices[i] = NA
      else
         local index = levelOf[element]
         if index then
            indices[i] = index
         else
            nextIndex = nextIndex + 1
            levelOf[element] = nextIndex
            indices[i] = nextIndex
         end
      end
      vp(2, 'mutated indices', indices, '#indices', #indices)
   end
         
   -- convert the levelOf table to a sequence by switching keys and values
   vp(2, 'levelOf table after all insertions', levelOf)
   local levels = {}
   for stringValue, levelNumber in pairs(levelOf) do
      levels[levelNumber] = stringValue
   end

   vp(1, 'indices', indices, 'levels', levels)
   return indices, levels
end -- asFactor
