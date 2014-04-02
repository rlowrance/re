-- tensorViewColumn_test.lua
-- unit test

require 'makeVp'
require 'tensorViewColumn'

local vp = makeVp(0, 'tester')

local nRows = 3
local nCols = 5
local t = torch.rand(nRows, nCols)
vp(2, 't', t)

local selectedCol = 2
local view = tensorViewColumn(t, selectedCol)
vp(2, 'view', view)

for i = 1, nRows do
   vp(2, 'i', i, 't value', t[i][selectedCol], 'view value', view[i])
   assert(t[i][selectedCol] == view[i])
end

print('ok tensorViewColumn')

