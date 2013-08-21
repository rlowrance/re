-- head.lua

require 'makeVp'

-- Return first n items of an obj
-- ARGS:
-- obj : sequence, 1D Tensor, 2D Tensor, or Dataframe
-- n   : integer >= 0, default 6; number of elements to return
-- RETURNS:
-- headObj : type(headObj) == type(obj) and contains the first n elements
--           for 2D Tensor, return first n rows
--           for Dataframe, return first n rows
function head(obj, n)
   local vp = makeVp(0, 'head')
   vp(1, 'obj', obj, 'n', n)
   vp(2, 'type(obj)', type(obj))
   assert(n == nil or type(n) == 'number')
   n = n or 6

   if type(obj) == 'table' then
      if torch.typename(obj) == 'Dataframe' then
         local newValues = {}
         for k, v in pairs(obj.values) do
            newValues[k] = head(v, n)
         end
         return Dataframe{values = newValues, levels = obj.levels}
      -- treat it as if it were a sequence
      else
         local result = {}
         for i, element in ipairs(obj) do
            if i > n then break end
            result[#result + 1] = element
         end
         return result
      end
   elseif type(obj) == 'userdata' then
      if obj:dim() == 1 then
         -- 1D tensor
         local nn = math.min(n, obj:size(1))
         local result = torch.Tensor(nn)
         for i = 1, nn do
            result[i] = obj[i]
         end
         return result
      elseif obj:dim() == 2 then
         -- 2D tensor
         local nn = math.min(n, obj:size(1))
         local result = torch.Tensor(nn, obj:size(2))
         for i = 1, nn do
            result[i] = obj[i]
         end
         return result
      else
         error('not implemented for more than 2 dimensions in Tensor')
      end
   else
      error('invalid type for obj; type = ' .. type(obj))
   end
end