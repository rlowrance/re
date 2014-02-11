-- unittest.lua
-- run all unit tests
--
-- A unit test is a program file ending in '_test.lua'

require 'directoryScan'

local src = '/home/roy/Dropbox/nyu-thesis-project/src.git'
local filenames = directoryScan(src)
for _, filename in ipairs(filenames) do
   if string.sub(filename, -9) == '_test.lua' then
      print('**********************************************starting test ' .. filename)
      dofile (filename)
      print('**********************************************finished test ' .. filename)
      print()
   end
end
print('finished all unit tests')
