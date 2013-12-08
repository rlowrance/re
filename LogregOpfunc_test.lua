-- LogregOpfunc_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'LogregOpfunc'
require 'Timer'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')

local testExample = {
nFeatures = 2,
nSamples = 2,
nClasses = 3,
X = torch.Tensor{{1,2}, {3,4}},
y = torch.Tensor{1, 3},
s = torch.Tensor{.1, .5},
lambda = .01
}

-- test private methods
local function _structureTheta_test()
   local vp = makeVp(0, '_structureTheta_test')
   local theta = torch.Tensor{1,2,3,4}
   vp(2, 'theta', theta)

   -- test 0
   local of = LogregOpfunc(testExample.X, testExample.y, testExample.s, 
                           testExample.nClasses, testExample.lambda)
   local theta = of:initialTheta()
   local biases, weights = of:_structureTheta(theta)
   
   assert(biases:nDimension() == 1)
   assert(biases:size(1) == testExample.nClasses - 1)
   assertEq(biases, torch.Tensor{theta[1], theta[4]}, 0)

   assert(weights:nDimension() == 2)
   assert(weights:size(1) == testExample.nFeatures)
   assert(weights:size(2) == testExample.nClasses - 1)
   assertEq(weights, 
            torch.Tensor{{theta[2], theta[3]},
                         {theta[5], theta[6]}},
            0)

   -- test 1
   local biases, weights = _structureTheta(theta, 2, 3)
   vp(2, 'biases', biases, 'weights', weights)
   assert(biases:nDimension() == 1 and biases:size(1) == 1)
   assert(weights:nDimension() == 2 and weights:size(1) == 1 and weights:size(2) == 3)
   assert(biases[1] == 1)
   assert(weights[1][1] == 2)
   assert(weights[1][2] == 3)
   assert(weights[1][3] == 4)

   -- test 2
   local biases, weights = _structureTheta(theta, 3, 1)
   assert(biases:nDimension() == 1 and biases:size(1) == 2)
   assert(weights:nDimension() == 2 and weights:size(1) == 2 and weights:size(2) == 1)
   assert(biases[1] == 1)
   assert(weights[1][1] == 2)
   assert(biases[2] == 3)
   assert(weights[2][1] == 4)
end

_structureTheta_test()
stop()


-- unit tests
local nSamples = 5
local nFeatures = 8
local nClasses = 3
local lambda = 0.001

local X = torch.rand(nSamples, nFeatures)

local y = torch.Tensor(nSamples)
local class = 0
for i = 1, nSamples do
   class = class + 1
   if class == nClasses then class = 1 end
   y[i] = class
end

local s = torch.Tensor(nSamples)
s:uniform(0, 1)

local of = LogregOpfunc(X, y, s, nClasses, lambda)
vp(2, 'of', of)

local parameters = of:initialParameters()
vp(2, 'parameters', parameters)
assert(parameters:nElement() == (nClasses - 1) * (nFeatures + 1))

-- change the parametes
for i = 1, parameters:size(1) do
   parameters[i] = i / 10
end

-- check that functions return something
if false then
    local loss, info = of:loss(parameters)
    vp(2, 'loss', loss, 'info', info)
    assert(type(loss) == 'number')
    assert(info.probs:size(1) == nSamples)
    assert(info.probs:size(2) == nClasses)

    local gradient = of:gradient(parameters, info)
    vp(2, 'gradient', gradient)
end

-- check loss function
local function checkLoss(theta, lambda, expectedLoss)
    local vp = makeVp(2, 'checkLoss')
    vp(1, 'theta', theta, 'lambda', lambda, 'expectedLoss', expectedLoss)
    local X = torch.Tensor{{1}, {2}}
    local y = torch.Tensor{1, 2}
    local s = torch.Tensor{.5, .1}
    local nClasses = 3

    local op = LogregOpfunc(X, y, s, nClasses, lambda)
    local loss, info = op:loss(theta)
    vp(2, 'loss', loss, 'info', info)
    stop()

    assertEq(expectedLoss, loss, 0.0001)
end

local thetaZero = torch.Tensor{0, 0, 0, 0}
local thetaZeroExpectedLoss = 0.38751
local lambda = 0.1
checkLoss(thetaZero, 0, thetaZeroExpectedLoss)
checkLoss(thetaZero, lambda, thetaZeroExpectedLoss)

local thetaOne = torch.Tensor{1, 1, 1, 1}
local lambda = 0.1
local thetaOneLogLikelihood = -.45109
local thetaOneRegularizer = 0.2
checkLoss(thetaOne, lambda, - thetaOneLogLikelihood + thetaOneRegularizer)
checkLoss(thetaOne, 0, - thetaOneLogLikelihood)
stop('delete following code to check Loss')

-- if all parameters are equal, probs of first nClasses - 1 are also equal
local equalParams = of:initialParameters():fill(1)
local loss, info = of:loss(equalParams)
vp(2, 'loss', loss, 'info.probs', info.probs)
for i = 1, X:size(1) do -- first nClasses -1 probs are equal in each obs
   for c = 2, nClasses - 1 do
      assertEq(info.probs[i][1], info.probs[i][c], 1e-10)
   end
end   

-- if all parameters are zero, probabilities are all equal
local zeroParams = of:initialParameters():zero()
local loss, info = of:loss(zeroParams)
vp(2, 'loss', loss, 'info.probs', info.probs)
for i = 1, X:size(1) do -- all probs are equal in each obs
   for c = 1, nClasses do
      assertEq(info.probs[i][1], info.probs[i][c], 1e-10)
   end
end   

-- if lambda goes to zero, loss changes by lambda * squared weights
do 
   local lambda = .1
   local of = LogregOpfunc(X, y, s, nClasses, lambda)
   local params = of:initialParameters()
   vp(2, 'params', params, 'of', of)
   local lossWithRegularizer = of:loss(params)

   local of = LogregOpfunc(X, y, s, nClasses, 0)
   local lossWithoutRegularizer, info = of:loss(params)
   vp(2, 'lossWithRegularizer', lossWithRegularizer, 
         'lossWithoutRegularizer', lossWithoutRegularizer)
   local weightsSquared = torch.cmul(info.weights, info.weights)
   local sumWeightsSquared = weightsSquared:sum()
   vp(2, 'sumWeightsSquared', sumWeightsSquared)
   local deltaLoss = lossWithRegularizer - lossWithoutRegularizer
   assertEq(deltaLoss, lambda * sumWeightsSquared, .0001)
end


-- check gradient 
-- turn off regularizer first
local function checkGradient(lambda, params, expectedLoss)   
   local vp = makeVp(2, 'tester::checkGradient')
   -- for now, have a very simple test case
   local X = torch.Tensor{{1}}
   local y = torch.Tensor{1}
   local s = torch.Tensor{1}
   local nClasses = 2
   local of = LogregOpfunc(X, y, s, nClasses, lambda)
   vp(2, 'initial params', params)
  
   local function opfunc(x) 
      return of:loss(x)
   end
  
   local loss, info = of:loss(params)
   vp(2, 'loss', loss, 'info', info)
   if expectedLoss ~= nil then
      assertEq(loss, expectedLoss, 1e03)
   end
   
   local grad = of:gradient(params, info)
   local eps = 1e-5
   local fdGrad = finiteDifferenceGradient(opfunc, params, eps)
   for i = 1, params:size(1) do
      vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, grad[i], i, fdGrad[i]))
   end
   assertEq(grad, fdGrad, .0001)
end

-- check using zero parameters
local paramsZero = torch.Tensor{0, 0}
checkGradient(0,  paramsZero, 0.69315) -- turn off regularizer
checkGradient(.1, paramsZero, 0.69315) -- with regularizer

local params2 = torch.Tensor{.1, .2}
checkGradient(0, params2, 0.55436)  -- without regularizer
checkGradient(.1, params2, 0.55436)  -- without regularizer

stop('write a test')

-- timing test
local timer = Timer()
local nIterations = 1000
for i = 1, nIterations do
   local loss, probs = of:loss(parameters)
end
vp(2, 'avg loss cpu', timer:cpu() / nIterations)
stop()
print('ok LogregOpfunc')
