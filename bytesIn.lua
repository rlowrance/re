-- bytesIn.lua

-- estimate number of bytes in object
function bytesIn(obj)
   local vp, verbose = makeVp(0, 'bytesIn')
   local d = verbose > 0
   vp(1, 'obj', obj)
   vp(1, 'type(obj)', type(obj))
   vp(1, 'torch.typename(obj)', torch.typename(obj))


   local bytesNumber = 8    -- number of bytes in a number
   local bytesPointer = 8   -- number of bytes in pointer

   local result = nil
   if torch.typename(obj) == 'torch.DoubleStorage' then
      local s = obj:size()
      result = s * bytesNumber
   elseif torch.typename(obj) == 'torch.DoubleTensor' then
      local nDim = obj:dim()
      result = 
         bytesPointer +                     -- pointer to storage
         bytesNumber +                      -- offset value
         nDim * 2 * bytesNumber +           -- strides + dims
         bytesIn(obj:storage())             -- storage itself
   elseif type(obj) == 'table' then
      -- assume 8 bytes per pointer
      -- assume 30% free space and hash structure
      -- assume every string is uniquely allocated (this isn't true, as
      -- strings are interned)
      local bytes = 0
      for k, v in pairs(obj) do
         bytes = bytes + bytesIn(k) + bytesIn(v)
         bytes = bytes + 2 * bytesPointer   -- for two pointers
      end
      bytes = bytes / .70                   -- 30% free space
      result = bytes
   elseif type(obj) == 'string' then
      -- strings are interned, so this is an upper bound
      -- assume pointer to interned storage
      result = bytesPointer + string.len(obj)
   elseif type(obj) == 'number' then
      result = bytesNumber + bytesPointer  -- pointer to nyumber        
   elseif type(obj) == nil then
      result = bytesPointer
   elseif type(obj) == 'boolean' then
      result = bytesPointer + 1  -- pointer to byte
   
   else
      vp(0, 'type(obj)', type(obj))
      vp(0, 'torch.typename(obj)', torch.typename(obj))
      error('not yet implemented')
   end

   vp(1, 'bytesIn result', result)
   return result
end