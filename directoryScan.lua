-- directoryScan.lua
-- return sequence of strings, one for each file in a specified directory
-- ARGS
-- directory : string containing absolute path
-- RETURNS
-- seq       : sequence of strings
-- NOTES: from stack overflow
function directoryScan(directory)
   local i = 0
   local t = {}
   local popen = io.popen  -- open a program in another process, returing readable file handle
   for filename in popen('ls -a "' .. directory .. '"'):lines() do
      table.insert(t, filename)
   end
   return t
end

