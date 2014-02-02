-- printTableValue_test.lua
-- unit test

require 'printTableValue'
require 'torch'

local actuallyPrint = true

if actuallyPrint then
   t1 = {one = 1, abc = 'abc'}
   printTableValue('t1', t1)
   printTableValue(t1)

   t2 = {def = 'def', nested = t1}
   printTableValue('t2', t2)
   printTableValue(t2)

   t3 = {}
   t3.one = 1
   t3.f = function() end
   t3.tensor1D = torch.Tensor(30)
   t3.tensor2D = torch.Tensor(3, 5)
   t3.storage = torch.Storage(10)
   printTableValue('t3', t3)
else
   print('printing disabled')
end

print('ok printTableValue')
