-- printTensorValue_test.lua
-- unit test

require 'printTensorValue'
require 'torch'

local verbose = false
if verbose then
   local t = torch.rand(10,10)

   printTensorValue('matrix t', t)
   printTensorValue(t, 10)
   printTensorValue(t, 3, 7)

   local v= torch.rand(10)
   printTensorValue('vector', v)
   printTensorValue('vector', v, 3)
end

print('ok printTensorValue')
