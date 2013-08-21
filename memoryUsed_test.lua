-- memoryUsed_test.lua
-- unit test

require 'makeVp'
require 'memoryUsed'

local verbose = 2
local vp = makeVp(verbose, 'tester')

if verbose > 0 then
   vp(1, 'memoryUsed', memoryUsed())
end

print('ok memoryUsed')