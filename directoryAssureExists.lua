-- assure directory exists, create it if it is not in the dir system
-- ARGS
-- dirPath: string, path to directory
-- 
-- RETURNS: nil or calls error if the directory path is invalid

require 'makeVp'
require 'validateAttributes'

function directoryAssureExists(dirPath)
   local vp = makeVp(1, 'directoryAssureExists')
   validateAttributes(dirPath, 'string')

   local command = 'mkdir -p ' .. dirPath -- -p ==> create parents, no error if existing
   local ok, str, num = os.execute(command)
   if ok then 
      return
   end

   error('mkdir failed; command=' .. command .. '; str= ' .. str .. '; num=' .. tostring(num))
end
