-- finiteDifferenceGradient_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'torch'

local vp = makeVp(0, 'tester')

local function f(x)
   local x1 = x[1]
   local x2 = x[2]
   local result = 5 * x1 ^ 2 + 3 * math.sin(x2^3) + 20 * x1 * x2
   return result
end

local x = torch.rand(2)
local eps = 1e-5

local function grad(x)
   local x1 = x[1]
   local x2 = x[2]

   local grad1 = 10 * x1 + 20 * x2
   local grad2 = 3 * math.cos(x2 ^ 3) * 3 * (x2 ^ 2) + 20 * x1

   local result = torch.Tensor{grad1, grad2}
   return result
end

local fdGrad = finiteDifferenceGradient(f, x, eps)
local analyticGradient = grad(x)
vp(2, 'fdGrad', fdGrad)
vp(2, 'analyticGradient', analyticGradient)
assertEq(analyticGradient, fdGrad, 10 * eps)

print('ok finiteDifferenceGradient')


