-- isnan_test.lua
-- unit test of isnan

require 'isnan'

-- test all types
assert(not isnan(nil))
assert(not isnan(true))
assert(not isnan(10))
assert(not isnan("abc"))
local function f() return true end
assert(not isnan(f))
assert(not isnan({}))

assert(isnan(0 / 0))

print('ok isnan')
