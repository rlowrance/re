-- delete an existing empty directory from the file system
-- fail if it is not deleted
-- ARGS
-- path : string, path to file or empty directory
--
-- RETURNS: nil or raises error if path is not valid

require 'makeVp'
require 'validateAttributes'

function directoryDelete(path)
   local vp = makeVp(0, 'directoryDelete')
   vp(1, 'path', path)
   validateAttributes(path, 'string')
   
   local result, err, code = os.remove(path)
   vp(2, 'result', result, 'str', str, 'number', number)
   if result == true then
      return
   end

   -- if result is nil, the call to os.remove has failed
   error('error=' .. err .. '; error code=' .. tostring(code))
end
