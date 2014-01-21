-- printTableValue_test.lua
-- unit test

require 'printTableValue'

local actuallyPrint = false

if actuallyPrint then
   t1 = {one = 1, abc = 'abc'}
   printTableValue('t1', t1)
   printTableValue(t1)

   t2 = {def = 'def', nested = t1}
   printTableValue('t2', t2)
   printTableValue(t2)
else
   print('printing disabled')
end

print('ok printTableValue')
