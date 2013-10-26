-- unit test

require 'directoryAssureExists'
require 'directoryAssureNotExists'
require 'directoryDelete'

local directoryPath = '/tmp/directoryAssureNotExists_test.tmp'

-- directory already exists
directoryAssureExists(directoryPath)
directoryAssureNotExists(directoryPath)
local exists = directoryExists(directoryPath)
assert(exists == false)

-- directory does not already exist
directoryAssureExists(directoryPath)
directoryDelete(directoryPath)
directoryAssureNotExists(directoryPath)
local exists = directoryExists(directoryPath)
assert(exists == false)

print('ok directoryAssureNotExists')
