-- keyboard_test.lua
-- unit test

require 'keyboard'
require 'makeVp'

local upvalue = 'abc'

local function f(a, b, ...)
   local f_local1 = 'f1'
   local f_local2 = 27
   local f_local3 = function () end
   local f_local4 = {...}  -- convert varargs to a list
   local function g(x)
      local g_local1 = 23
      local g_local2 = 'g%abc'
      local x = upvalue
      for i = 1, 1 do  
         keyboard('unit test')
      end
   end
   g(12)
end

-- execute call to f to run a test
local interactWithUser = false
if interactWithUser then  
   f(10, 20, 'vararg1', 'vararg2')
else
   print('tests disabled')
end


print('ok keyboard')
