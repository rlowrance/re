-- printTensorValue_test.lua
-- unit test

require 'printTensorValue'
require 'torch'

local t = torch.rand(10,10)

printTensorValue('matrix t', t)
printTensorValue(t, 10)
printTensorValue(t, 3, 7)

local v= torch.rand(10)
printTensorValue('vector', v)
printTensorValue('vector', v, 3)
stop()

print('ok printTensorValue')
