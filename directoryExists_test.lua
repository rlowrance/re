-- directoryExists_test.lua
-- unit test

require 'directoryAssureExists'
require 'directoryDelete'
require 'directoryExists'
require 'makeVp'

local vp = makeVp(2, 'tester')

local path = '/tmp/directoryExists_test.dir'

-- create directory if it doesn't exist
directoryAssureExists(path)
assert(directoryExists(path))

-- remove it and test again
directoryDelete(path)
assert(not directoryExists(path))

print('ok directoryExists')
