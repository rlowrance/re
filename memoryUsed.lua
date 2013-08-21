-- memoryUsed.lua

-- total memory used in bytes
function memoryUsed()
   collectgarbage('collect')  -- first collect all the garbage
   local k = collectgarbage('count') -- count kilobytes used
   return k * 1024
end
