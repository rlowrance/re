-- directoryExists: return true iff specified directory exists
-- ARGS
-- path : string, path to directory
--
-- RETURNS: boolean

require 'makeVp'
require 'validateAttributes'

function directoryExists(path)
   local vp = makeVp(0, 'fileExists')
   vp(1, 'path', path)
   validateAttributes(path, 'string')
  
   local f, err = io.open(path, 'r')
   if f == nil then
      -- there was an error
      -- assume it was because the file did not exist
      vp(2, 'err', error)
      return false
   else
      f:close()
      return true
   end
end
