-- makeVp_rtest.lua
-- regression test

require 'makeVp'

local function f()
end

-- one-off tests when problems are found
local vp = makeVp(1, 'one-off tests')
local s = {1,2,3}
vp(1, 's', s)


-- one value of each type: 
-- nil, boolean, number, string, function, userdata, thread (omitted), table
local values = {nil, true, 123, 'abc', f, torch.rand(2,3), {a=10,b=20}}
local names = 
   {'nilValue', 'trueValue', 'num123', 'sabc', 'functionF', 'tensor', 'table'}

print('values=') print(values)
print('names=') print(names)


local function check(verbose)
   local vp, verboseLevel, prefix = makeVp(verbose, 'check')
   --print('makeVp results') print(vp) print(verboseLevel) print(prefix)
   assert(type(vp) == 'function')
   assert(verboseLevel == verbose)
   assert(prefix == 'check')

   -- always print value
   print('\nstarting to print just values')
   for i, name in ipairs(names) do
      print('values[' .. i .. ']=' .. tostring(values[i]))
      vp(values[i])
   end

   -- always print name = value
   -- NOTE: vp(name, nil) does not print name=nil because it looks like vp(name)
   print('\nstarting to print name=value')
   for i, name in ipairs(names) do
      vp(name, values[i])
   end

   -- test special case 
   -- the call looks just like vp('aName')
   vp('aName', nil)  -- does not print "aName=nil"

   -- conditionally print no varargs
   print('\nstring to print conditionally name=value')
   for i, name in ipairs(names) do
      vp(1, name, values[i])
   end

   -- test strange case
   vp(1, 'aName', nil)  -- prints "aName"

   -- conditionally print with varargs
   print('starting conditional value prints with varargs')
   for i, name in ipairs(names) do
      local x = 456
      local z = torch.rand(4, 5)
      vp(1, name, values[i], 'x', x, 'z', z)
   end
   
end

check(0) -- no printing of conditional values
check(1) -- all printing

print('ok regression test makeVp')
