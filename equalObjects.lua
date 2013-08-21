-- equalObjects.lua

require 'equalTensors'
require 'makeVp'

-- are two arbitrary objects equal in value (not necessarily the same object)
-- ARGS
-- a      : arbitrary object
-- b      : arbitrary object
-- RETURNS
-- result : boolean
function equalObjects(a, b)
   local vp = makeVp(0, 'equalObjects')
   vp(1, '\n************')
   vp(1, 'a', a, 'b', b)
   vp(1, 'type(a)', type(a))
   vp(1, 'torch.typename(a)', torch.typename(a))

   if type(a) ~= type(b) then
      vp(1, 'result', false)
      return false
   end

   if type(a) == 'table' then
      -- is every element in a also in b
      local function allIn(a, b)
         for k, v in pairs(a) do
            local result = equalObjects(v, b[k])
            if result == false then
               return false
            end
         end
         return true
      end

      local result = allIn(a, b) and allIn(b, a)
      vp(1, 'result', result)
      return result

   elseif type(a) == 'userdata' then
      if torch.typename(a) ~= torch.typename(b) then
         vp(1, 'result', false)
         return false
      end

      local torchTypename = torch.typename(a)
      if torchTypename == 'torch.DoubleTensor' or
         torchTypename == 'torch.FloatTensor' or
         torchTypename == 'torch.IntTensor' or
         torchTypename == 'torch.CharTensor' or
         torchTypename == 'torch.BoolTensor' then
         local result = equalTensors(a, b)
         vp(1, 'result', result)
         return result
      elseif torchTypename == 'NamedMatrix' then
         local result = a:equalValue(b)
         vp(1, 'result', result)
         return result
      else
         error(string.format('torch.typename %s not yet implemented', 
                             torch.typename(a)))
      end

   else
      local result = a == b
      vp(1, 'result', result)
      return result
   end
end