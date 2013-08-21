-- isSequence_test.lua

require 'isSequence'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

assert(isSequence({1,2,3}))
assert(not isSequence({1,2,nil,4}))
assert(not isSequence({1,2,3,x='ab'}))

print('ok isSequence')