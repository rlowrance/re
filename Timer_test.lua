-- Timer_test.lua
-- unit test of Timer.lua

require 'Timer'

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

