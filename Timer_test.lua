-- Timer_test.lua
-- unit test of Timer.lua

require 'makeVp'
require 'Timer'

local vp = makeVp(0, 'tester')

-- new version of API
timer = Timer('main program', io.stderr)
timer:lap('one')
for i = 1, 10000000 do local x = i * i end
timer:lap('two')
timer:write()

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

