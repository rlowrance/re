-- unit test

require 'fileDelete'
require 'fileExists'
require 'makeVp'

local filePath = '/tmp/fileExists_test.txt'

-- create test file
local f, err = io.open(filePath, 'w')
f:close()

-- now delete it
fileDelete(filePath)

assert(not fileExists(filePath))

-- create test file
local f, err = io.open(filePath, 'w')
f:close()

assert(fileExists(filePath))

fileDelete(filePath)

print('ok fileDelete')

