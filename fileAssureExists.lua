-- assure file exists, create it if it is not in the file system
-- ARGS
-- filePath: string, path to file
-- 
-- RETURNS: nil

require 'fileExists'
require 'makeVp'
require 'validateAttributes'

function fileAssureExists(filePath)
   local vp = makeVp(1, 'fileAssureExists')
   validateAttributes(filePath, 'string')

   if fileExists(filePath) then
      return
   end

   local f, err = io.open(filePath, 'w')
   if f == nil then
      -- there was an error
      assert(false, 
             'unable to create file at path=' .. filePath .. 
             '; err=' .. err)
   end
end
