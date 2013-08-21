-- parseCommandLine_test.lua
-- unit test

require 'makeVp'
require 'parseCommandLine'

local clArg = {'x', '-a', '--b', '27'}

local r = parseCommandLine(clArg, 'present', 'x')
assert(r == true)

local r = parseCommandLine(clArg, 'present', '-a')
assert(r == true)

local r = parseCommandLine(clArg, 'present', '-c')
assert(r == false)

local r = parseCommandLine(clArg, 'value', '--b')
assert(r == '27')

local r = parseCommandLine(clArg, 'value', '--c')
assert(r == nil)

print('ok parseCommandLine')