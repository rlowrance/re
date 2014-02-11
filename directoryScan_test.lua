-- directoryScan_test.lua
-- unit test

require 'directoryScan'
require 'makeVp'

-- configure
config = {verbose = false}

local seq = directoryScan('/home/roy/Dropbox/nyu-thesis-project/src.git')
for _, filename in ipairs(seq) do
   if config.verbose then
      print(filename)
   end
end

print('ok directoryScan')
