-- tensorViewColumn_test.lua
-- unit test

require 'makeVp'
require 'tensorViewColumn'

local vp = makeVp(0, 'tester')

local nRows = 3
local nCols = 5
local t = torch.rand(nRows, nCols)
vp(2, 't', t)

local function testColumn(colIndex)
   local vp = makeVp(0, 'testColumn')
   local view = tensorViewColumn(t, colIndex)
   vp(2, 'view', view)

   for i = 1, nRows do
      vp(2, 'i', i, 't value', t[i][selectedCol], 'view value', view[i])
      assert(t[i][colIndex] == view[i], tostring(colIndex))
   end
end

-- test all potential columns
for colIndex = 1, nCols do
   testColumn(colIndex)
end

print('ok tensorViewColumn')

