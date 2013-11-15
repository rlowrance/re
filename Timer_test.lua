-- Timer_test.lua
-- unit test of Timer.lua

require 'makeVp'
require 'Timer'

local vp = makeVp(2, 'tester')

-- new version of API
timer = Timer(vp)
timer:lap('one')
timer:lap('two')
timer:verbose(1, 'cpu')
timer:verbose(1, 'wallclock')

-- old version of API (still supported)
timer = Timer()
assert(timer:wallclock() >= timer:cpu())
assert(timer:user() >= 0)
assert(timer:system() >= 0)
local cpu, wallclock = timer:cpuWallclock()
assert(cpu <= wallclock)

local oldTime = timer:wallclock()
timer:reset()
assert(oldTime >= timer:wallclock())

print('ok Timer')

