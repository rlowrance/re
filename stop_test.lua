-- stop_test.lua
-- unit test

require 'makeVp'
require 'stop'

local vp, verboseLevel = makeVp(0, 'tester')

local function f(a, b, c)
   vp(2, 'in f') -- an up value
   stop('i am stopping')
end

if verboseLevel > 0 then 
   f(1, 2, 3) 
end

print('ok stop')

