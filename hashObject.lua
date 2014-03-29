-- hashObject.lua


local function numericHash(object)

   local function hashNil()
      return 0
   end

   local function hashBoolean(bool)
      local boolbase = 100
      if bool then return 1 + boolbase
      else         return 0 + boolbase
      end
   end

   local function hashNumber(number)
      return number
   end

   local function hashString(str)
      local sum = string.len(str)
      for i = 1, string.len(str) do
         sum = sum + string.byte(str, i, i) * i
      end
      return sum
   end

   local function hashDoubleTensor1D(tensor)
      local size1 = tensor:size(1)

      local sum = 0
      local position = 1
      sum = sum + hashNumber(size1) * position

      for i = 1, tensor:size(1) do
         position = position + 1
         sum = sum + tensor[i] * position
      end

      return sum
   end

   local function hashDoubleTensor2D(tensor)
      local size1 = tensor:size(1)
      local size2 = tensor:size(2)

      local position = 1
      local sum = 0
      local sum = hashNumber(size1) * position 

      position = position + 1 
      local sum = sum + hashNumber(size2) * position

      for rowIndex = 1, size1 do
         for colIndex = 1, size2 do
            position = position + 1
            sum = sum + tensor[rowIndex][colIndex] * position
         end
      end
      return sum
   end

   local function hashDoubleTensor(tensor)
      local nDimension = tensor:nDimension()
      if nDimension == 1 then return hashDoubleTensor1D(tensor)
      elseif nDimension == 2 then return hashDoubleTensor2D(tensor)
      else error('unimplemented nDimension ' .. tostring(nDimension))
      end
   end

   local function hashUserdata(object)
      local torchtype = torch.typename(object)
      if torchtype == 'torch.DoubleTensor' then return hashDoubleTensor(object)
      else error('unknown userdata type ' .. torchtype)
      end
   end

   local function hashTable(tab)
      local sum = 0
      local elementNum = 0
      for k, v in pairs(tab) do
         elementNum = elementNum + 1
         sum = sum + numericHash(k) * elementNum
         elementNum = elementNum + 2
         sum = sum + numericaHash(v) * elementNum
      end
      return sum
   end

   local t = type(object)
   if     t == 'nil' then return hashNil()
   elseif t == 'boolean' then return hashBoolean(object)
   elseif t == 'number' then return hashNumber(object)
   elseif t == 'string' then return hashString(object)
   elseif t == 'function' then error('cannot has a function')
   elseif t == 'userdata' then return hashUserdata(object)
   elseif t == 'thread' then error('cannot has a thread')
   elseif t == 'table' then return hashTable(object)
   else error('impossible')
   end
end

-- digest the value stored in the object into a string
-- RETURN
-- hashcode : string such that 
--   x ~= y ==> hashcode(x) ~= hashcode(y), with high probability
--   x == y ==> hashcode(x) == hashcode(y), with certainty
function hashObject(object)
   return tostring(numericHash(object))
end
