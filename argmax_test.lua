-- argmax_test.lua
-- unit test for argmax

require 'argmax'
require 'assertEq'
require 'ifelse'
require 'makeVp'
require 'printAllVariables'
require 'printTableVariable'
require 'Timer'

local vp = makeVp(0, 'tester')

-- Don't set the random seed, since we make multiple runs to check the timing
--torch.manualSeed(123)

local function test1D(nElements)
   local v = torch.rand(nElements)
   local maxIndex = argmax(v)
   --printAllVariables() 
   assert(type(maxIndex) == 'number')

   local max = torch.max(v)
   assert(max == v[maxIndex])
end

test1D(3)
test1D(100)

local function test2D(nRows, nColumns)
   local vp = makeVp(0, 'test2D')
   local v = torch.rand(nRows, nColumns)
   local maxIndices = argmax(v)
   assert(maxIndices:nDimension() == 1)
   assert(maxIndices:size(1) == nRows)

   local maxValues = torch.max(v, 2) -- maxValues is size nRows x 1
   vp(2, 'v', v, 'maxIndices', maxIndices, 'maxValues', maxValues)
   for i = 1, nRows do
      --print(maxValues[i]) print(maxIndices[i]) print(v[i])
      vp(2, 'maxValues[i]', maxValues[i])
      vp(2, 'maxIndices[i]', maxIndices[i])
      vp(2, 'v[i][maxIndices[i]', v[i][maxIndices[i]])
      local maxValue = maxValues[i][1]
      assertEq(maxValue, v[i][maxIndices[i]], .00001)
   end
end

test2D(5, 3)
test2D(120, 8)
-- MAYBE: check timing
print('ok argmax')



