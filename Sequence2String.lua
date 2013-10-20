-- Sequence2String.lua
-- conversion of a sequence to a string
-- useful in forming a table with keys or values that are sequences

require 'makeVp'
require 'splitString'
require 'validateAttributes'

if false then
   -- API Overview
   ss = Sequence2String{types={'string','number'},
                        separator='-',}

   -- convert sequence to string
   s = ss:toString(value1, value2)

   -- convert string to sequence
   seq = ss:toSequence(s) -- type(seq[1]) == 'string', type[seq[2]) == 'number'
end

-- construction
local Sequence2String = torch.class('Sequence2String')

function Sequence2String:__init(t)
   local vp = makeVp(0, 'Sequence2String:__init')
   vp(1, 't.types', t.types, 't.separator', t.separator)
   validateAttributes(t, 'table')
   validateAttributes(t.separator, 'string')

   self.types = t.types
   self.separator = t.separator
end

-- convert sequence to string
function Sequence2String:toString(values)
   local vp = makeVp(0, 'Sequence2String:toString')
   vp(1, 'values', values)
   validateAttributes(values, 'table')  -- a sequence

   local s = ''
   for i, value in ipairs(values) do
      if i > 1 then s = s .. self.separator end
      s = s .. tostring(value)
      vp(1, 'i', i, 's', s)
   end

   return s
end

-- convert string back to sequence
function Sequence2String:toSequence(string)
   local vp = makeVp(0, 'Sequence2String:toSequence')
   vp(1, 'string', string)

   local seqStrings = splitString(string, self.separator)

   -- convert the sequence of strings to a sequence of the correct types
   local result = {}
   for i, typeName in ipairs(self.types) do
      if typeName == 'string' then
         table.insert(result, seqStrings[i])
      elseif typeName == 'number' then
         table.insert(result, tonumber(seqStrings[i]))
      else
         assert(false, 'typeName not known: ' .. typeName)
      end
   end

   return result
end
