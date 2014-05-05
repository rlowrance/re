-- object.lua
-- useful functions that operate on arbitrary objects

if false then
   nBytes = object.nBytes(obj)   -- bytes in the object
end

object = {}

-- ref: www.wowwiki.com/Lua_object_memory_sizes
function object.nBytes(obj)
   local function bytesTensor(elementBytes, tensor)
      return tensor:nElement() * elementBytes
   end

   local t = type(obj)
   if t == 'boolean' then
      return 8
   elseif t == 'nil' then
      return 8
   elseif t == 'number' then
      return 8
   elseif t == 'function' then
      -- each closure takes 20 bytes
      -- each upvalue that is constant takes 4 bytes
      -- each upvalue that may change takes 36 bytes
      return 20  -- assume no upvalues
   elseif t == 'string' then
      -- average memory consumption is 24 + length of strength
      -- strings are interned
      return 24 + string.len(obj)
   elseif t == 'thread' then
      return 16
   elseif t == 'table' then
      -- the table may have preallocated members
      -- this code doesn't see them
      -- each element in the array part takes 16 bytes
      -- each element in the hash part takes 40 bytes
      local sum = 0
      for k, v in pairs(obj) do
         if type(k) == 'number' then
            sum = sum + 16  -- assume all number keys are in the array part
         else
            sum = sum + 40 + object.nBytes(k) + object.nBytes(v)
         end
      end
      return sum
   elseif t == 'userdata' then
      local tt = torch.typename(obj)
      if tt == 'torch.IntTensor' or tt == 'torch.FloatTensor' then
         return bytesTensor(4, obj)
      elseif tt == 'torch.LongTensor' or tt == 'torch.DoubleTensor' then
         return bytesTensor(8, obj)
      elseif tt == 'torch.CharTensor' or tt == 'torch.ByteTensor' then
         return bytesTensor(1, obj)
      else
         return 8 + #obj   -- some say that #obj is the size of the user data
      end
   else
      error('type(obj)', t)
   end
end
