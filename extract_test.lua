-- extract_test.lua
-- unit test

require 'extract'
require 'makeVp'

local verbose = 2
local vp = makeVp(verbose, 'tester')

local va = {'a', 10, 'b', 20}
assert(extract(va, 'a', 100) == 10)
assert(extract(va, 'b', 100) == 20)
assert(extract(va, 'c', 100) == 100)

print('ok extract')