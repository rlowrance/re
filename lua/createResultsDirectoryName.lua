-- createResultsDirectoryName.lua

require 'sortedKeys'

-- return string containing directory name to hold results
-- ARGS
-- programName : string, becomes first part of result
-- options     : table st options.optionName = suppliedValue
-- defaults    : table st default.optionName = defaultValue
function createResultsDirectoryName(programName, options, defaults)
   assert(programName)
   assert(options)
   assert(defaults)

   -- determine sorted option names
   optionNames = sortedKeys(options)

   -- build up the result string
   local result = programName
   for i = 1, #optionNames do
      local optionName = optionNames[i]
      local optionValue = options[optionName]
      local defaultValue = defaults[optionName]
      if optionValue ~= defaultValue then
         result = result .. ',' ..  optionName .. '=' .. tostring(optionValue)
      end
   end

   return result
end