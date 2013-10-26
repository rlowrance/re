-- directoryDelete_test
-- unit test

require 'directoryAssureExists'
require 'directoryDelete'
require 'directoryExists'
require 'makeVp'

local vp = makeVp(0, 'tester')

local path = '/tmp/directoryDelete_test'

-- delete directory that exists
directoryAssureExists(path)
directoryDelete(path)
assert(not directoryExists(path))

-- delete directory that does not exist: should fail
local statusCode = pcall(directoryDelete, path)
vp(2, 'statusCode', statusCode)
assert(statusCode == false)

print('ok directoryDelete')

