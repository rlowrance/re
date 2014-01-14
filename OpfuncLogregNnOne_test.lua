-- OpfuncLogregNnOne_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'OpfuncLogregNnOne'
require 'printVariable'
require 'printAllVariables'
require 'printTableVariable'
require 'Random'
require 'Timer'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')


-- UNIT TESTS

-- setup unit test example


local function makeUnitTestExample(lambdaValue)
   local vp = makeVp(0, 'makeUnitTestExample')
   -- inputs
   lambdaValue = lambdaValue or .01  -- supply default value
   local testExample = {
      nFeatures = 2,
      nSamples = 2,
      nClasses = 3,
      X = torch.Tensor{{1,2}, {3,4}},
      y = torch.Tensor{1, 3},
      s = torch.Tensor{.1, .5},
      lambda = lambdaValue,
      theta = torch.Tensor{-1, 2, -3, 4, -5, 6, -7, 8, -9}}  -- biases are last 3 entries

   -- outputs
   local function w(index)
      return testExample.theta[index]
   end

   testExample.sumSquaredWeights = 
      w(1) * w(1) + w(2) * w(2) + w(3) * w(3) + w(4) * w(4) + w(5) * w(5) + w(6) * w(6)


   -- unnormalized probabilities for sample 1
   local score11 = -7 - 1 * 1 + 2 * 2  -- prob that sample 1 has value 1
   local score12 = 8 - 3 * 1 + 4 * 2   -- prob that sample 1 has value 2
   local score13 = -9 - 5 * 1 + 6 * 2  -- prob that sample 1 has value 3
   vp(2, string.format('scores for sample: %f %f %f', score11, score12, score13))

   -- normalized probabilies for sample 1
   local normalizer = math.exp(score11) + math.exp(score12) + math.exp(score13)
   testExample.prob11 = math.exp(score11) / normalizer  -- prob that sample 1 has value  1
   testExample.prob12 = math.exp(score12) / normalizer
   testExample.prob13 = math.exp(score13) / normalizer
   vp(2, string.format('probs for sample 1: %f %f %f',
                       testExample.prob11,
                       testExample.prob12,
                       testExample.prob13))
   testExample.logProb11 = math.log(testExample.prob11)
   testExample.logProb12 = math.log(testExample.prob12)
   testExample.logProb13 = math.log(testExample.prob13)
   vp(2, string.format('log probs for sample 1: %f %f %f',
                       testExample.logProb11,
                       testExample.logProb12,
                       testExample.logProb13))

                       
   testExample.expectedLossSample1 = 
      17 * testExample.s[1] + testExample.lambda * (testExample.sumSquaredWeights)

   vp(2, 'OpfuncLogregNnOne', OpfuncLogregNnOne)
   local of =  OpfuncLogregNnOne(testExample.X, 
                                 testExample.y, 
                                 testExample.s, 
                                 testExample.nClasses, 
                                 testExample.lambda)

   return of, testExample
end
      
-- test default implementation of private methods support runLoss() method

local function _gradientLossLogprobabilities_test()
   local vp = makeVp(0, '_lossGradient_test')
   local of, testExample = makeUnitTestExample()
   
   local sampleIndex = 1
   local gradient, loss, logProbabilities = of:_gradientLossLogprobabilities(testExample.theta, sampleIndex)
   vp(1, 'gradient', gradient, 'loss', loss, 'logProbabilities', logProbabilities)
   assert(gradient:nDimension() == 1)
   assert(gradient:size(1) == 9)

   assertEq(loss, testExample.expectedLossSample1, .0001)

   assert(logProbabilities:nDimension() == 1)
   local probabilities = torch.exp(logProbabilities)
   local sum = torch.sum(probabilities)
   assertEq(sum, 1, .00001)
end

if true then
   _gradientLossLogprobabilities_test()
else
   print('skipped _gradientLossLogprobabilities_test')
end
   
-- test public methods
-- test loss method first, because the test of the gradient method depends on the loss method working

local function initialTheta_test()
   local vp = makeVp(0, 'initialTheta_test')
   local of, testExample = makeUnitTestExample()
   local initialTheta = of:initialTheta()
   vp(2, 'initialTheta', initialTheta)

   assert(initialTheta:nDimension() == 1)
   assert(initialTheta:size(1) == (testExample.nClasses) * (testExample.nFeatures + 1))
end

initialTheta_test()

-------------------------------------------------------------------------------

local function loss_test(lambda)
   local vp = makeVp(0, 'loss_test')
   local of, testExample = makeUnitTestExample(lambda)

   -- test on first randomly-selected sample
   local loss = of:loss(testExample.theta)

   local expectedLoss = 17 * testExample.s[1] + testExample.lambda * (testExample.sumSquaredWeights)
   vp(2, 'sumSquaredWeights', testExample.sumSquaredWeights, 'lambda', testExample.lambda)
   assertEq(loss,  expectedLoss, .0001)  -- since y == 1 on sample 1

   -- test on second randomly-selected sample
   -- MAYBE do this later
end

loss_test(0)  -- first with no regularizer
loss_test(.01)  -- then with regularizer

-------------------------------------------------------------------------------

local function gradient_test_returns_same(lambda)
   -- make sure that public method gradient and private method _lossGradient return the same value
   -- do this because the test of the gradient value relies on calling the private method
   -- NOTE: this test was stubbed out because the current API doesn't provide a way to determine the 
   -- index of the last sample
   if true then
      return
   end

   local vp = makeVp(0, 'gradient_test_returns_same')
   local of = makeUnitTestExample(lambda)
   local theta = of:initialTheta()  -- use random theta

   local loss, lossInfo = of:loss(theta)
   local gradientFromPublicMethod = of:gradient(lossInfo)
   vp(2, 'lossInfo', lossInfo, 'gradientFromPublicMethod', gradientFromPublicMethod)

   local loss2, gradientFromPrivateMethod = of:_gradientLossLosProbabilities(theta, lossInfo.i) -- use same sample
   vp(2, 'gradientFromPrivateMethod', gradientFromPrivateMethod)

   assertEq(gradientFromPublicMethod, gradientFromPrivateMethod, .0001)
end

local function gradient_test_gradient_value(lambda)   
   -- make sure the gradient value returned by the private method _lossGradient is correct
   -- call the private method so that the index of the sample to use can be specified
   local vp = makeVp(0, 'gradient_test_gradient_value')
   local of, testExample = makeUnitTestExample(lambda)
   local sampleIndex = 1

   local function f(theta)
      vp(3,'theta in f', theta)
      local loss, _ = of:_lossLogprobabilities(theta, sampleIndex)
      return loss
   end
  
   local gradient, _ , _ = of:_gradientLossLogprobabilities(testExample.theta, sampleIndex)
   vp(2, 'gradient', gradient)

   local eps = 1e-5
   local eps = .0001  -- just for testing
   vp(2, 'testExample.theta', testExample.theta)
   local fdGradient = finiteDifferenceGradient(f, testExample.theta, eps)
   for i = 1, testExample.theta:size(1) do
      vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, gradient[i], i, fdGradient[i]))
   end
   assertEq(gradient, fdGradient, .0001)
end

-- test gradient in two steps, because the public method gradient(lossInfo) selects a random sample
local function gradient_test(lambda)
   gradient_test_returns_same(lambda)
   gradient_test_gradient_value(lambda)
end

if true then
   gradient_test(0)     -- first test without the regularizer
   gradient_test(.001)  -- now test with the regularizer
end

print('ok OpfuncLogregNnOne')
