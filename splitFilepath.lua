-- splitFilepath.lua
-- split a string that is a file path into its parts
-- ARGS
-- filepath : string
-- RETURNS
-- dir : string containing the path to the directory
-- filename : string containing the actual file name
-- lastComponent : string containing the file suffix of the filename, if no suffix
function splitFilepath(filepath)
   return string.match(filepath, '(.-)([^\\/]-%.?([^%.\\/]*))$')
end
