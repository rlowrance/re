-- splitTensor.lua

-- randomly split 2D Tensor into two pieces (e.g., test and train)
--
-- ARGS
--
-- t: 2D Tensor
--
-- fractionTest: number, fraction to test Tensor
--
-- RETURNS: test and train Tensors
function splitTensor(t, fractionTest)
   local function vp(x)
      if true then print(x) end
   end

   assert(fractionTest >=0, 'fractionTest must be non-negative')

   -- identify rows that will be in test subset
   local nRows = t:size(1)
   local inTest = torch.Tensor(nRows):zero()  -- initially none in test subset
   local nTest = 0
   for i = 1, nRows do
      if torch.uniform(0, 1) < fractionTest then
         inTest[i] = 1  -- row i is in test subset
         nTest = nTest + 1
      end
   end
   --vp('nTest=' .. nTest)
   --vp('inTest'); vp(inTest)

   local nCols = t:size(2)
   local test = torch.Tensor(nTest, nCols)
   local train = torch.Tensor(nRows - nTest, nCols)
   --vp('test'); vp(test); vp('train'); vp(train); vp('inTest'); vp(inTest)

   local testRowIndex = 0
   local trainRowIndex = 0
   for i = 1, nRows do
      if inTest[i] == 1 then
         testRowIndex = testRowIndex + 1
         --vp('testRowIndex=' .. testRowIndex); vp('i=' .. i)
         test[testRowIndex] = t[i]
      else
         trainRowIndex = trainRowIndex + 1
         train[trainRowIndex] = t[i]
      end
   end

   return test, train
end