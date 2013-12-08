-- functionName.lua
-- return name of the function
function functionName()
   local stackLevel = 2 -- level of caller to this function
   local info = debug.getinfo(stackLevel)
   return info.name
end
