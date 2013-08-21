-- validateAttributes_test.lua
-- unit test

require 'makeVp'
require 'validateAttributes'

local vp = makeVp(0, 'tester')

local tensor = torch.Tensor(3,8)
local s = 'abc'
local n = 27
local b = boolean
local tab = {1,2,3}
local function f() end

-- check types
validateAttributes(torch.rand(3,8), 'torch.DoubleTensor', 'size', {3,8})
validateAttributes(torch.FloatTensor(3,8), 'Tensor')
validateAttributes('abc', {'nil', 'string'})
validateAttributes(27, 'number', 'nonnegative')
validateAttributes(true, 'boolean')
validateAttributes({1,2,3}, 'table', 'size', 3)
validateAttributes(function () end, 'function')
validateAttributes(nil, 'nil')
validateAttributes(27, {'string', 'number'})

local function fail(arg1, arg2, arg3, arg4)
   local status = pcall(validateAttributes, arg1, arg2, arg3, arg4)
   assert(status == false)
end

-- check attributes
validateAttributes(torch.rand(3), 'Tensor', '1d')
validateAttributes(torch.rand(3), 'Tensor', '1D')
fail(torch.rand(3,8), 'Tensor', '1d')

validateAttributes(torch.rand(3,8), 'Tensor', '2d')
validateAttributes(torch.rand(3,8), 'Tensor', '2D')
fail(torch.rand(3), 'Tensor', '2d')

validateAttributes(torch.rand(3,1), 'Tensor', 'column')
fail(torch.rand(3), 'Tensor', 'column')

validateAttributes(torch.rand(1,3), 'Tensor', 'row')
fail(torch.rand(2,3), 'Tensor', 'row')

validateAttributes(torch.rand(1,1), 'Tensor', 'scalar')
fail(torch.rand(1), 'Tensor', 'scalar')

validateAttributes(torch.rand(2,1), 'Tensor', 'vector')
validateAttributes(torch.rand(1,2), 'Tensor', 'vector')
fail(torch.rand(2,3), 'Tensor', 'vector')

validateAttributes(torch.rand(2,3), 'Tensor', 'size', {2,3})
fail(torch.rand(2,3), 'Tensor', 'size', {2,4})

validateAttributes(torch.rand(2,3), 'Tensor', 'nElement', 6)
fail(torch.rand(2,3), 'Tensor', 'nElement', 60)

validateAttributes(torch.rand(2,3), 'Tensor', 'nCols', 3)
fail(torch.rand(2,3), 'Tensor', 'nCols', 30)

validateAttributes(torch.rand(2,3), 'Tensor', 'nRows', 2)
fail(torch.rand(2,3), 'Tensor', 'nRows', 20)

validateAttributes(torch.rand(2,3), 'Tensor', 'nDimension', 2)
fail(torch.rand(2,3), 'Tensor', 'nDimension', 20)

validateAttributes(torch.rand(2,2), 'Tensor', 'square')
fail(torch.rand(2,3), 'Tensor', 'square')

validateAttributes(torch.rand(2,2), 'Tensor', 'nonempty')
fail(torch.Tensor(0,2), 'Tensor', 'nonempty')

validateAttributes(torch.Tensor{{1,2},{3,4}}, 'Tensor', '>', 0)
fail(torch.Tensor{{1,2},{3,4}}, 'Tensor', '>', 1)
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)


validateAttributes(torch.Tensor{{1,2},{3,4}}, 'Tensor', '>=', 1)
fail(torch.Tensor{{1,2},{3,4}}, 'Tensor', '>=', 2)
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{{1,2},{3,4}}, 'Tensor', '<', 5)
fail(torch.Tensor{{1,2},{3,4}}, 'Tensor', '<', 4)
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{{1,2},{3,4}}, 'Tensor', '<=', 4)
fail(torch.Tensor{{1,2},{3,4}}, 'Tensor', '<=', 3)
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{2,4}, 'Tensor', 'even')
fail(torch.Tensor{2,4,1}, 'Tensor', 'even')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1,3}, 'Tensor', 'odd')
fail(torch.Tensor{1,3,4}, 'Tensor', 'odd')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{{1,3}}, 'Tensor', 'integer')
fail(torch.Tensor{{1,3, 5.1}}, 'Tensor', 'integer')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1, 2}, 'Tensor', 'finite')
fail(torch.Tensor{1, 1/0}, 'Tensor', 'finite')
fail(torch.Tensor{1, -1/0}, 'Tensor', 'finite')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1, 2}, 'Tensor', 'nonnan')
fail(torch.Tensor{1, 0/0}, 'Tensor', 'nonNan')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1, 0}, 'Tensor', 'nonnegative')
fail(torch.Tensor{1, -1}, 'Tensor', 'nonNegative')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1, 2}, 'Tensor', 'nonzero')
fail(torch.Tensor{1, 0}, 'Tensor', 'nonZero')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{1, 2}, 'Tensor', 'positive')
fail(torch.Tensor{1, 0}, 'Tensor', 'positive')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

validateAttributes(torch.Tensor{-1, -2}, 'Tensor', 'negative')
fail(torch.Tensor{1, 0}, 'Tensor', 'negative')
validateAttributes(27, 'number', '>', 10)
fail(27, 'number', '>', 28)

fail(torch.Tensor{1,2}, 'Tensor', 'unknown-attribute')

print('ok validateAttributes')