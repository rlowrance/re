-- CommandLine_test.lua
-- unit test

require 'CommandLine'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local arg = {'--x', 'abc', '--flag', '--y', '123'}

-- construction
local cl = CommandLine(arg)

-- isPresent
assert(cl:isPresent('--x'))
assert(cl:isPresent('abc'))
assert(cl:isPresent('--flag'))
assert(not cl:isPresent('--z'))

-- maybeValue
assert(cl:maybeValue('--x') == 'abc')
assert(cl:maybeValue('--y') == '123')
assert(cl:maybeValue('--z') == nil)

-- required
assert(cl:required('--x') == 'abc')
assert(cl:required('--y') == '123')

-- defaultable
assert(cl:defaultable('--x', 'default') == 'abc')
assert(cl:defaultable('--y', 'default') == '123')
assert(cl:defaultable('--z', 'default') == 'default')

print('ok CommandLine')

