-- LogregOpfunc_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'LogregOpfunc'
require 'printValue'
require 'printAllValues'
require 'printTable'
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
lambda = .01,
theta=torch.Tensor{-1, 2, -3, 2, -4, 5}
}

local function makeOfFromTestExample()
   return LogregOpfunc(testExample.X, 
                       testExample.y, 
                       testExample.s, 
                       testExample.nClasses, 
                       testExample.lambda)
end
      
-- test private methods

local function _structureTheta_test()
   local of = makeOfFromTestExample()
   local theta = testExample.theta
   local biases, weights = of:_structureTheta(theta)
   
   assert(biases:nDimension() == 1)
   assert(biases:size(1) == testExample.nClasses - 1)
   assert(biases[1] == theta[1])
   assert(biases[2] == theta[4])

   assert(weights:nDimension() == 2)
   assert(weights:size(1) == testExample.nFeatures)
   assert(weights:size(2) == testExample.nClasses - 1)
   assert(weights[1][1] == theta[2])
   assert(weights[1][2] == theta[3])
   assert(weights[2][1] == theta[5])
   assert(weights[2][2] == theta[6])
end

_structureTheta_test()


local function _scores_test()
   local of = makeOfFromTestExample()
   local biases, weights = of:_structureTheta(testExample.theta)
   local scores = of:_scores(biases, weights)

   assert(scores:nDimension() == 2)
   assert(scores:size(1) == 2)
   assert(scores:size(2) == 3)

   assert(scores[1][1] == biases[1] + torch.dot(testExample.X[1], weights[1]))
   assert(scores[1][2] == biases[2] + torch.dot(testExample.X[1], weights[2]))
   assert(scores[1][3] == 0)

   assert(scores[2][1] == biases[1] + torch.dot(testExample.X[2], weights[1]))
   assert(scores[2][2] == biases[2] + torch.dot(testExample.X[2], weights[2]))
   assert(scores[2][3] == 0)
end

_scores_test()


local function _probabilities_test()
   local of = makeOfFromTestExample()
   local biases, weights = of:_structureTheta(testExample.theta)
   local scores = of:_scores(biases, weights)
   local probabilities = of:_probabilities(scores)
   
   assert(probabilities:nDimension() == 2)
   assert(probabilities:size(1) == testExample.nSamples)
   assert(probabilities:size(2) == testExample.nClasses)

   -- expected values computed in octave script LogregOpfunc_test.m
   assertEq(probabilities[1], torch.Tensor{2.2596e-6, 9.9966e-1, 3.3535e-4}, .0001)
   assertEq(probabilities[2], torch.Tensor{4.1397e-8, 9.9995e-1, 4.5398e-5}, .0001)
end

_probabilities_test()


local function _logLikelihood_test()
   local of = makeOfFromTestExample()
   local biases, weights = of:_structureTheta(testExample.theta)
   local scores = of:_scores(biases, weights)
   local probabilities = of:_probabilities(scores)
   local logLikelihood = of:_logLikelihood(probabilities)
   printAllValues()

   local prob11 = 2.2596e-6  -- probability that y[1] == 1
   local prob23 = 4.5398e-5  -- probability that y[2] == 3
   local expectedLikelihood = prob11 ^ testExample.s[1] * prob23 ^ testExample.s[2]
   local expectedLogLikelihood = math.log(expectedLikelihood)
   printAllValues()

   assertEq(logLikelihood, expectedLogLikelihood, .0001)
   testExample.expectedLogLikelihood = expectedLogLikelihood
end

_logLikelihood_test()


local function _regularizer_test()
   local of = makeOfFromTestExample()
   local biases, weights = of:_structureTheta(testExample.theta)
   local regularizer = of:_regularizer(weights)
   printAllValues()
   printValue('testExample.theta')
   local expectedRegularizer = testExample.theta[2]^2 + testExample.theta[3]^2 +
                               testExample.theta[5]^2 + testExample.theta[6]^2
   assertEq(regularizer, expectedRegularizer, .00001)
   testExample.expectedRegularizer = expectedRegularizer
end

_regularizer_test()

-- test public methods

local function loss_test()
   local of = makeOfFromTestExample()
   local loss = of:loss(testExample.theta)
   local expectedLoss = -testExample.expectedLogLikelihood + 
                        testExample.lambda * testExample.expectedRegularizer

   assertEq(loss, expectedLoss, .0001)
end

loss_test()

local function gradient_test()   
   -- for now, test without a regularizer
   testExample.lambda = 0
   local of = makeOfFromTestExample()

   local function f(theta)
      return of:loss(theta)
   end
  
   local loss, info = of:loss(testExample.theta)
   local gradient = of:gradient(testExample.theta, info)

   local eps = 1e-5
   local fdGradient = finiteDifferenceGradient(opfunc, testExample.theta, eps)
   for i = 1, testExample.theta:size(1) do
      vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, gradient[i], i, fdGradient[i]))
   end
   assertEq(gradient, fdGradient, .0001)
end

gradient_test()

stop()


-- timing test
local timer = Timer()
local nIterations = 1000
for i = 1, nIterations do
   local loss, probs = of:loss(parameters)
end
vp(2, 'avg loss cpu', timer:cpu() / nIterations)
stop()
print('ok LogregOpfunc')
