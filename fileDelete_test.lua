-- unit test

require 'fileDelete'
require 'makeVp'

local filePath = '/tmp/fileDelete_test.txt'

-- file must 
local f, err = io.open(filePath, 'w')
f:close()

-- now delete it
fileDelete(filePath)

print('ok fileDelete')

