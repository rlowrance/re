-- unique.lua

-- Return sequence of unique values in a given sequence or table
-- ARGS:
-- t         : a seq or table or Tensor
--             if a table, only the values are considered (not the keys)
--             if a Tensor, must be 1D or 2D
-- RETURNS
-- uniqueSeq : a sequence containing just the unique values in seq
function unique(t)
   -- build set of unique values, so that uniqueElements[v] := true
   local uniqueElements = {}
   if type(t) == 'table' then
      for k, v in pairs(t) do
         if not uniqueElements[v] then
            uniqueElements[v] = true
         end
      end
   elseif type(t) == 'userdata' and t:dim() == 1 then
      for i = 1, t:size(1) do
         uniqueElements[t[i]] = true
      end
   elseif type(t) == 'userdata' and t:dim() == 2 then
      for r = 1, t:size(1) do
         for c = 1, t:size(2) do
            uniqueElements[t[r][c]] = true
         end
      end
   else
      error('bad type or dim for t; type(t) = ' .. type(t))
   end
         
   -- convert the set into a sequence
   local result = {}
   for k, v in pairs(uniqueElements) do
      table.insert(result, k)
   end

   return result
end
