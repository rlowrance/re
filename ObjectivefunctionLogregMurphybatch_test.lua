-- ObjectivefunctionLogregMurphybatch_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'ObjectivefunctionLogregMurphybatch'
require 'printVariable'
require 'printAllVariables'
require 'printTableVariable'
require 'Random'
require 'Timer'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')


-- UNIT TESTS

-- setup unit test example


local function makeUnitTestExample()
   -- inputs
   local testExample = {
      nFeatures = 2,
      nSamples = 2,
      nClasses = 3,
      X = torch.Tensor{{1,2}, {3,4}},
      y = torch.Tensor{1, 3},
      s = torch.Tensor{.1, .5},
      lambda = .01,
      theta=torch.Tensor{-1, 2, -3, 2, -4, 5}}

   -- outputs
   testExample.expectedRegularizer = testExample.theta[2]^2 + testExample.theta[3]^2 +
                                     testExample.theta[5]^2 + testExample.theta[6]^2


   local prob11 = 2.2596e-6  -- probability that y[1] == 1
   local prob23 = 4.5398e-5  -- probability that y[2] == 3
   local expectedLikelihood = prob11 ^ testExample.s[1] * prob23 ^ testExample.s[2]
   testExample.expectedLogLikelihood = math.log(expectedLikelihood)

   local of =  ObjectivefunctionLogregMurphybatch(testExample.X, 
                                       testExample.y, 
                                       testExample.s, 
                                       testExample.nClasses, 
                                       testExample.lambda)
   return of, testExample
end
      
-- test default implementation of private methods support runLoss() method

local function _loss_regularizer_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_loss_structureTheta(testExample.theta)
   local regularizer = of:_loss_regularizer(thetaInfo)
   assertEq(regularizer, testExample.expectedRegularizer, .00001)
end

_loss_regularizer_test()

local function _loss_logLikelihood_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_loss_structureTheta(testExample.theta)
   local scores = of:_loss_scores(thetaInfo)
   local probabilities = of:_loss_probabilities(scores)
   local logLikelihood = of:_loss_logLikelihood(probabilities)

   assertEq(logLikelihood, testExample.expectedLogLikelihood, .0001)
end

_loss_logLikelihood_test()

local function _loss_probabilities_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_loss_structureTheta(testExample.theta)
   local scores = of:_loss_scores(thetaInfo)
   local probabilities = of:_loss_probabilities(scores)
   
   assert(probabilities:nDimension() == 2)
   assert(probabilities:size(1) == testExample.nSamples)
   assert(probabilities:size(2) == testExample.nClasses)

   -- expected values computed in octave script ObjectivefunctionLogreg_test.m
   assertEq(probabilities[1], torch.Tensor{2.2596e-6, 9.9966e-1, 3.3535e-4}, .0001)
   assertEq(probabilities[2], torch.Tensor{4.1397e-8, 9.9995e-1, 4.5398e-5}, .0001)
end

_loss_probabilities_test()

local function _loss_regularizer_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_loss_structureTheta(testExample.theta)
   local regularizer = of:_loss_regularizer(thetaInfo)
   local expectedRegularizer = testExample.theta[2]^2 + testExample.theta[3]^2 +
                               testExample.theta[5]^2 + testExample.theta[6]^2
   assertEq(regularizer, expectedRegularizer, .00001)
   testExample.expectedRegularizer = expectedRegularizer
end

_loss_regularizer_test()


local function _loss_scores_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_loss_structureTheta(testExample.theta)
   local biases = thetaInfo.biases
   local weights = thetaInfo.weights
   local scores = of:_loss_scores(thetaInfo)

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

_loss_scores_test()



local function _loss_structureTheta_test() 
   local of, testExample = makeUnitTestExample()
   local theta = testExample.theta
   local thetaInfo = of:_loss_structureTheta(theta)
   local biases = thetaInfo.biases
   local weights = thetaInfo.weights
   local W = thetaInfo.W
   
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

   assert(W:nDimension() == 2)
   assert(W:size(1) == testExample.nClasses)
   assert(W:size(2) == testExample.nFeatures + 1)
   assert(W[1][1] == theta[1])
   assert(W[1][2] == theta[2])
   assert(W[1][3] == theta[3])
   assert(W[2][1] == theta[4])
   assert(W[2][2] == theta[5])
   assert(W[2][3] == theta[6])
end

_loss_structureTheta_test()


-------------------------------------------------------------------------------
-- TEST PUBLIC METHODS
-------------------------------------------------------------------------------

local function initialTheta_test()
   local of, testExample = makeUnitTestExample()
   local initialTheta = of:initialTheta()

   assert(initialTheta:nDimension() == 1)
   assert(initialTheta:size(1) == (testExample.nClasses - 1) * (testExample.nFeatures + 1))
end

initialTheta_test()

-------------------------------------------------------------------------------

local function gradient_test(lambda)   
   local vp = makeVp(0, 'gradient_test')
   local of, testExample = makeUnitTestExample()
   testExample.lambda = lambda


   local function f(theta)
      return of:loss(theta)
   end
  
   local gradient = of:gradient(testExample.theta)

   local eps = 1e-5
   local fdGradient = finiteDifferenceGradient(f, testExample.theta, eps)
   for i = 1, testExample.theta:size(1) do
      vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, gradient[i], i, fdGradient[i]))
   end
   assertEq(gradient, fdGradient, .0001)
end

gradient_test(0)  -- first test without the regularizer
gradient_test(.001)  -- now test with the regularizer

-------------------------------------------------------------------------------

local function loss_test()
   local of, testExample = makeUnitTestExample()
   local loss = of:loss(testExample.theta)
   local expectedLoss = -testExample.expectedLogLikelihood + 
                        testExample.lambda * testExample.expectedRegularizer

   assertEq(loss, expectedLoss, .0001)
end

loss_test()

-------------------------------------------------------------------------------

local function lossGradient_test()
   -- just test form of returned values
   local of, testExample = makeUnitTestExample()
   local loss, gradient, predictions = of:lossGradient(testExample.theta)
   assert(type(loss) == 'number')
   assert(loss >= 0)

   assert(gradient:nDimension() == 1)
end

lossGradient_test()

-------------------------------------------------------------------------------

local function predictions_test()
   if true then
      -- skip test, as not implemented
      return
   end
   local of, testExample = makeUnitTestExample()
   local newX = testExample.X:clone()
   local probabilities = of:predictions(newX, testExample.theta)
   printVariable('probabilities')
   error('write test')
end

predictions_test()

-------------------------------------------------------------------------------

print('ok ObjectivefunctionLogregMurphybatch')
