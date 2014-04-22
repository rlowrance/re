-- tableCount_test.lua
-- unit test

require 'tableCount'

local n = 10
local t = {}
for i = 1, n do
   t[math.random()] = math.random()
end
t['abc'] = {1, 2, 3}

assert(tableCount(t) == n + 1)
print('ok tableCount')
