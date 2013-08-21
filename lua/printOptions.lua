-- printOptions.lua

require 'sortedKeys'

function printOptions(options, log)
   -- print or log parameters
   -- ARGS
   -- options : table of options
   -- log     : option Log instance
   --           if supplied, write to log
   --           if not supplied, print
   local function p(line)
      if log then
         log:log(line)
      else
         print(line)
      end
   end -- p

   p('Command line options')

   local keys = sortedKeys(options)

   for i = 1, #keys do
      local key = keys[i]
      local value = options[key]
      local line = string.format('%17s %s', key, tostring(value))
      p(line)
   end
end -- printOptions
