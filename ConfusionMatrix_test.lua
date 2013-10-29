-- ConfusionMatrix_test.lua
-- unit test

require 'assertEqual'
require 'ConfusionMatrix'
require 'makeVp'

local vp, verboseLevel = makeVp(0, 'tester')

local cm = ConfusionMatrix()

for i = 1, 1 do cm:add(1, 1) end
for i = 1, 2 do cm:add(1, 2) end
for i = 1, 3 do cm:add(1, 3) end
for i = 1, 4 do cm:add(2, 1) end
for i = 1, 5 do cm:add(2, 2) end
for i = 1, 6 do cm:add(2, 3) end
for i = 1, 7 do cm:add(3, 1) end
for i = 1, 8 do cm:add(3, 2) end
for i = 1, 9 do cm:add(3, 3) end

if verboseLevel > 0 then 
   cm:printTo(io.stdout, 'test')
end

local errRate = cm:errorRate()
assertEqual(30 / 45, errRate, .01)

print('ok ConfusionMatrix')
