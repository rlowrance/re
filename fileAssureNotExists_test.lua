-- unit test

require 'fileAssureExists'
require 'fileAssureNotExists'
require 'fileDelete'

local filePath = '/tmp/fileAssureNotExists_test.tmp'

-- file already exists
fileAssureExists(filePath)
fileAssureNotExists(filePath)
local exists = fileExists(filePath)
assert(exists == false)

-- file does not already exist
fileAssureExists(filePath)
fileDelete(filePath)
fileAssureNotExists(filePath)
local exists = fileExists(filePath)
assert(exists == false)

print('ok fileAssureNotExists')
