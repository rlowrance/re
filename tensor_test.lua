--tensor_test.lua
--unit test

require 'makeVp'
require 'tensor'
require 'torch'

local vp = makeVp(0, 'tester')

local function test_concatenateHorizontally()
   local vp = makeVp(2, 'test_concatentateHorizontally')
   local nRows = 3
   local t1 = torch.rand(nRows)
   local t2 = torch.rand(nRows)
   local t3 = torch.rand(nRows)
   local t4 = torch.rand(nRows)
   local r = tensor.concatenateHorizontally(t1, t2, t3, t4)
   assert(t1[1] == r[1][1])
   assert(t2[2] == r[2][2])
   assert(t3[3] == r[3][3])
   assert(t4[1] == r[1][4])
end

test_concatenateHorizontally()

local function test_selected()
   local t = torch.DoubleTensor({1, 2, 3})
   local r = tensor.selected(t, torch.Tensor{2})
   assert(r:nDimension() == 1)
   assert(r:size(1) == 1)
   assert(r[1] == 2)
   assert(torch.typename(r) == 'torch.DoubleTensor')


   local t = torch.IntTensor({1, 2, 3})
   local r = tensor.selected(t, torch.LongTensor{2})
   assert(r:nDimension() == 1)
   assert(r:size(1) == 1)
   assert(r[1] == 2)
   assert(torch.typename(r) == 'torch.IntTensor')
end

test_selected()

local function test_viewColumn()
   local nRows = 3
   local nCols = 5
   local t = torch.rand(nRows, nCols)
   vp(2, 't', t)

   local function testColumn(colIndex)
      local vp = makeVp(0, 'testColumn')
      local view = tensor.viewColumn(t, colIndex)
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
end

test_viewColumn()

local function test_viewPrefix()
   local tDouble = torch.Tensor({1,2,3})
   local function test(t)
      local view = tensor.viewPrefix(t, 2)
      assert(view:nDimension() == 1)
      assert(view:size(1) == 2)
      assert(view[1] == t[1])
      assert(view[2] == t[2])
   end

   test(torch.Tensor({1,2,3}))
   test(torch.LongTensor({1,2,3}))
end

test_viewPrefix()

print('ok tensor')
