-- assertEq_test.lua

require 'assertEq'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

function expectError(fn, ...)
   local ok = pcall(fn, ...)
   assert(not ok)
end

local function runAssertEq(a, b, tolerance)
   local assertVerboseLevel = -1  -- -1 ==> no printing at all 
   assertEq(a, b, tolerance, assertVerboseLevel)
end

-- check numbers
runAssertEq(.1, .15, .05)
expectError(runAssertEq, .1, .15, .01)
expectError(.1, 'abc', .1)

-- check 1D Tensors
local a = torch.Tensor{1, 2}
local b = torch.Tensor{1.1, 2.2}
runAssertEq(a, b, .21)
expectError(runAssertEq, a, b, .1)
expectError(runAssertEq, a, 23, 1)

-- check 2D Tensors
local a = torch.Tensor{{1, 2}, {11, 12}}
local b = a + .1
vp(1, 'b', b)
runAssertEq(a, b, .15)
expectError(runAssertEq, a, b, .1)
expectError(runAssertEq, a, torch.Tensor{1, 2, 1.1, 2.2}, .15)

print('ok assertEq')

