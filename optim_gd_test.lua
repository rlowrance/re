-- optim_gd_test.lua
-- unit test

require 'makeVp'
require 'optim_gd'

local verbose = 0
local vp = makeVp(verbose,'unit tester')

-- TEST 1: convergence without adjusting alpha
-- minimize function from Heath p 277
-- f(x) = 0.5 x_1 ^ 2 + 2.5 x_2^2
-- minimizer is x = [0, 0]
-- starting point is x = [5 1]
-- alpha = 1/3 

local iteration = 1
local function convergedF(newLoss, newTheta)
   local vp = makeVp(0, 'convergedF')
   iteration = iteration + 1
   vp(1, string.format('%d: loss %f theta %f %f', 
                       iteration, newLoss, newTheta[1], newTheta[2]))
   return math.abs(newLoss) < 1e-6
end

-- gradient is [x1, 5 x2]
local function gradientF(theta)
   local x1 = theta[1]
   local x2 = theta[2]
   return torch.Tensor{x1, 5 * x2}
end

local function lossF(theta)
   local x1 = theta[1]
   local x2 = theta[2]
   return .5 * x1 * x1 + 2.5 * x2 * x2
end

local alpha = 1/3
local theta = torch.Tensor{5, 1}
vp(2, 'original loss', lossF(theta))
local finalLoss, finalTheta, finalAlpha  = optim.gd(alpha,
                                                    theta,
                                                    convergedF,
                                                    gradientF,
                                                    lossF)
vp(1, 'finalLoss', finalLoss)
vp(1, 'finalTheta', finalTheta)
vp(1, 'finalAlpha', finalAlpha)

local function assertEq(t1, t2, tol)
   local diff = t1 - t2
   local distance = torch.cmul(diff, diff):sum()
   return distance < tol
end

assertEq(theta, 0, .001)

-- TEST 2: failed to converge, as alpha is too high
local alpha = 100
local theta = torch.Tensor{5, 1}
vp(2, 'original loss', lossF(theta))
local ok, finalLoss, finalTheta, finalAlpha  = pcall(optim.gd,alpha,
                                                              theta,
                                                              convergedF,
                                                              gradientF,
                                                              lossF)
vp(1, 'ok', ok)
vp(1, 'error message', finalLoss)
if ok then assert(false, 'expected failure') end
assert(type(finalLoss) == 'string')

-- TEST 3: failed to converge, as alpha is too high
local alpha = 100
local theta = torch.Tensor{5, 1}
vp(2, 'original loss', lossF(theta))
local finalLoss, finalTheta, finalAlpha  = optim.gd(alpha,
                                                    theta,
                                                    convergedF,
                                                    gradientF,
                                                    lossF,
                                                    'decrease')
vp(1, 'finalLoss', finalLoss)
vp(1, 'finalTheta', finalTheta)
vp(1, 'finalAlpha', finalAlpha)

assertEq(theta, 0, .001)
assert(finalAlpha < alpha)

print('ok optim_gd')

