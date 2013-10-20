-- delete an existing file or empty directory from the file system
-- fail if it is not deleted
-- ARGS
-- filePath : string, path to file or empty directory
--
-- RETURNS: nil

require 'makeVp'
require 'validateAttributes'

function fileDelete(filePath)
   local vp = makeVp(0, 'fileDelete')
   vp(1, 'filePath', filePath)
   validateAttributes(filePath, 'string')
   
   local result, err, code = os.remove(filePath)
   vp(2, 'result', result, 'str', str, 'number', number)
   if result == true then
      return
   end

   -- if result is nil, the call to os.remove has failed
   assert(result ~= nil, 'error=' .. err .. '; error code=' .. tostring(code))
end
