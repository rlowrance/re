-- return true iff file exists
-- ARGS
-- filePath : string, path to file or empty directory
--
-- RETURNS: boolean

require 'makeVp'
require 'validateAttributes'

function fileExists(filePath)
   local vp = makeVp(0, 'fileExists')
   vp(1, 'filePath', filePath)
   validateAttributes(filePath, 'string')
  
   local f, err = io.open(filePath, 'r')
   if f == nil then
      -- there was an error
      -- assume it was because the file did not exist
      vp(2, 'file was not opened; err', err)
      return false
   else
      vp(2, 'file was opened')
      f:close()
      return true
   end
end
