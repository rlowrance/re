-- assure that a directory does not exists
-- if it does, delete it
-- ARGS
-- directoryPath : string, path to directory
--
-- RETURNS: nil

require 'directoryDelete'
require 'directoryExists'
require 'makeVp'
require 'validateAttributes'

function directoryAssureNotExists(directoryPath)
   local vp = makeVp(0, 'directoryAssureNotExists')
   validateAttributes(directoryPath, 'string')

   if not directoryExists(directoryPath) then
      return 
   end

   directoryDelete(directoryPath)
end
