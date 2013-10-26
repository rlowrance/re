-- directoryAssureExists_test.lua
-- unit test

require 'directoryAssureExists'
require 'directoryAssureNotExists'
require 'directoryDelete'
require 'makeVp'

local vp = makeVp(2, 'tester')

local dir = '/tmp/directoryAssureExists_test'

-- test case: directory does not exist
directoryAssureNotExists(dir)
directoryAssureExists(dir)

-- test case: directory already exists
directoryAssureExists(dir)

print('ok directoryAssureExists')

