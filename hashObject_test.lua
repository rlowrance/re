-- hashObject_test.lua
-- unit test

require 'hashObject'
require 'makeVp'
require 'torch'

local function printObjHash(obj)
   local hashString = hashObject(obj)
   print(string.format('hashObject(%s) = %s', tostring(obj), hashString))
end

printObjHash(nil)

printObjHash(true)
printObjHash(false)

printObjHash(123)
printObjHash(123.1)

printObjHash('a')
printObjHash('ab')
printObjHash('ba')

printObjHash(torch.Tensor({1}))
printObjHash(torch.Tensor({1, 2}))

t = torch.rand(3,5)
printObjHash(t)
t[2][3] = 0
printObjHash(t)

print('ok hashObject')
