-- luajit1G.lua
-- find 1 GB limit in lua

if jit == nil then
   error('jit is not running')
end

nElements = 1
while true do
   nElements = 2 * nElements 
   seq = {}
   for i = 1, nElements do
      seq[i] = 10 * i
   end
   
   print('elements ' .. tostring(nElements) 
         .. ' bytes used: ' .. tostring(collectgarbage('count')))
end