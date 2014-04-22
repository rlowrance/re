-- tableSplit_test.lua
-- unit test

require 'pp'
require 'tableCount'
require 'tableSplit'

t = {}
local n = 10
for i = 1, n do
   t[math.random()] = math.random()
end

pp.table('t', t)
local t1, t2 = tableSplit(t)
pp.table('t1', t1)
pp.table('t2', t2)

local function eachIsIn(a, b)
   for k, v in pairs(a) do
      if b[k] ~= v then 
         return false
      end
   end
   return true
end

assert(n == tableCount(t1) + tableCount(t2))
assert(eachIsIn(t1, t))
assert(eachIsIn(t2, t))

print('ok tableSplit')
