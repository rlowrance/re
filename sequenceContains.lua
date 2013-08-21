-- sequenceContains.lua

-- return true if value is in a sequence
function sequenceContains(seq, value)
   assert(type(seq) == 'table', 'seq must be a sequence')
   for _, seqValue in ipairs(seq) do
      if seqValue == value then
         return true
      end
   end
   return false
end