-- assure that a file does not exists
-- if it does, delete it
-- ARGS
-- filePath : string, path to file
--
-- RETURNS: nil

require 'fileDelete'
require 'fileExists'
require 'makeVp'
require 'validateAttributes'

function fileAssureNotExists(filePath)
   local vp = makeVp(0, 'fileAssureNotExists')
   validateAttributes(filePath, 'string')

   if not fileExists(filePath) then
      return 
   end

   fileDelete(filePath)
end
