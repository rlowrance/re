-- tableFilter_test.lua
-- unit test

require 'makeVp'
require 'printTableValue'
require 'tableFilter'


local vp, verboseLevel = makeVp(0, 'tester')
local debug = verboseLevel > 0

local t = {
   two = 'xx',
   three = 'something',
}
t[1] = 'one'

local function predicate(k, v)
   return type(k) == 'number' or v == 'xx'
end

local r = tableFilter(t, predicate)
if debug then printTableValue('r', r) end
assert(r[1] == 'one')
assert(r.two == 'xx')

print('ok tableFilter')

