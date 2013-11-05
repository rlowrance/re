-- CommandLine.lua
-- parse command line with only '--NAME VALUE' arguments
-- NOTE: Can later be extended to include other types of arguments

-- API overview
if false then
   cl = CommandLine(arg)

   flag = cl.isPresent('--flag')       -- true or false
   strOrNil = cl.maybeValue('--flag')  -- if not present, return nil
   arg1 = cl.required('--arg1')        -- errors if not present
   arg2 = cl.defaultable('--arg2', 'default value')
end

require 'makeVp'
require 'parseCommandLine'
require 'validateAttributes'

-- construction
local CommandLine = torch.class('CommandLine')

function CommandLine:__init(arg)
   validateAttributes(arg, 'table')
   self.arg = arg
end

-- isPresent(key)
function CommandLine:isPresent(key)
   local vp = makeVp(0, 'CommandLine:isPresent')
   vp(1, 'key', key)
   validateAttributes(key, 'string')
   return parseCommandLine(self.arg, 'present', key)
end

-- maybeValue(key)
function CommandLine:maybeValue(key)
   validateAttributes(key, 'string')
   return parseCommandLine(self.arg, 'value', key)  -- return nil if not present
end

-- required(key)
function CommandLine:required(key)
   validateAttributes(key, 'string')
   local str = parseCommandLine(self.arg, 'value', key)
   assert(str ~= nil, 'missing keyword ' .. key)
   return str
end

-- defaultable(key, defaultValue)
function CommandLine:defaultable(key, defaultValue)
   local vp = makeVp(2, 'CommandLine:defaultable')
   vp(1, 'key', key, 'defaultValue', defaultValue)
   validateAttributes(key, 'string')
   validateAttributes(defaultValue, {'string', nil})
   local str = parseCommandLine(self.arg, 'value', key)
   if str == nil then
      vp(2, 'returning default value', defaultValue)
      return defaultValue
   else
      vp(2, 'returning supplied value', str)
      return str
   end
end
