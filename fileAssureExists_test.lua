-- unit test

require 'fileAssureExists'
require 'fileDelete'
require 'makeVp'

local filePath = '/tmp/fileAssureExists_test.tmp'

-- create test file
local f, err = io.open(filePath, 'w')
f:close()

-- file already exists
fileAssureExists(filePath)

-- file does not already exist
fileDelete(filePath)
fileAssureExists(filePath)

print('ok fileAssureExists')

