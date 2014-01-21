-- ObjectivefunctionLogregNnbatch.lua
-- unit test

require 'finiteDifferenceGradient'
require 'ObjectivefunctionLogregNnbatch'
require 'printVariable'
require 'printAllVariables'
require 'printTableVariable'
require 'Random'
require 'Timer'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')


-- UNIT TESTS

-- setup unit test example


-- RETURN
-- example : table containing X, y, s, and other values
local function makeRandomExample(lambda)
   local vp = makeVp(0, 'makeRandomExample')
   lambda = lambda or .01

   local nFeatures = 5
   local nSamples = 10
   local nClasses = 4

   local X = torch.rand(nSamples, nFeatures)
   local y = Random:integer(nSamples, 1, nClasses)
   local s = Random:uniform(nSamples, .0001, 1)

   local theta = torch.rand((nFeatures + 1) * nClasses)
   local initialTheta = ObjectivefunctionLogregNnbatch(X, y, s, nClasses, lambda):initialTheta()
   vp(2, 'theta', theta, 'initialTheta', initialTheta)
   assert(initialTheta:nDimension() == 1)
   assert(theta:size(1) == initialTheta:size(1))

   local example = {
      theta = theta,  -- theta where the loss is known
      expectedLossOnBatch = nil,  -- don't compute it, as must then reimplement the class we are testing
      lambda = lambda,
      nFeatures = nFeatures,
      nSamples = nSamples,
      nClasses = nClasses,
      X = X,
      y = y,
      s = s}


   --printTableVariable('example')
   return example

end
   


-- ARGS
-- lambdaValue : optional number, value of lambda in the example
-- RETURN
-- of      : instance of ObjectivefunctionLogreg for the example
-- example : table containing X, y, s, and other values
local function makeKnownExample(lambdaValue)
   local vp = makeVp(0, 'makeKnownExample')
   lambdaValue = lambdaValue or .01
   local function makeExample()
      return {
         nFeatures = 2,
         nSamples = 2,
         nClasses = 3,
         X = torch.Tensor{{1,2}, {3,4}},
         y = torch.Tensor{1, 3},
         s = torch.Tensor{.1, .5},
         lambda = lambdaValue,
         theta = torch.Tensor{-1, 2, -3, 4, -5, 6, -7, 8, -9}}  -- biases are last 3 entries
   end

   local function sumSquaredWeights(example)
      local function w(index)
         return example.theta[index]
      end
      return w(1) * w(1) + w(2) * w(2) + w(3) * w(3) + w(4) * w(4) + w(5) * w(5) + w(6) * w(6)
   end

   -- DETERMINE LOSS WE EXPECT FOR SAMPLE 1
   -- NOTE: The calculations automate a hand-calculation
   local function expectedLossOnSample1FirstMethod(example)
      local score11 = -7 - 1 * 1 + 2 * 2  -- prob that sample 1 has value 1
      local score12 = 8 - 3 * 1 + 4 * 2   -- prob that sample 1 has value 2
      local score13 = -9 - 5 * 1 + 6 * 2  -- prob that sample 1 has value 3
      vp(2, string.format('scores for sample: %f %f %f', score11, score12, score13))

      -- normalized probabilies for sample 1
      local normalizer = math.exp(score11) + math.exp(score12) + math.exp(score13)
      example.prob11 = math.exp(score11) / normalizer  -- prob that sample 1 has value  1
      example.prob12 = math.exp(score12) / normalizer
      example.prob13 = math.exp(score13) / normalizer
      vp(2, string.format('probs for sample 1: %f %f %f',
      example.prob11,
      example.prob12,
      example.prob13))
      example.logProb11 = math.log(example.prob11)
      example.logProb12 = math.log(example.prob12)
      example.logProb13 = math.log(example.prob13)
      vp(2, string.format('log probs for sample 1: %f %f %f',
      example.logProb11,
      example.logProb12,
      example.logProb13))

      return 17 * example.s[1] + example.lambda * (example.sumSquaredWeights)
   end

   local function expectedLossOnSample(example, sampleIndex)
      local vp = makeVp(0, 'expectedLossOnSample')
      local w1 = torch.Tensor{example.theta[1], example.theta[2]}
      local w2 = torch.Tensor{example.theta[3], example.theta[4]}
      local w3 = torch.Tensor{example.theta[5], example.theta[6]}
      local b1 = example.theta[7]
      local b2 = example.theta[8]
      local b3 = example.theta[9]
      local score1 = b1 + torch.dot(example.X[sampleIndex], w1)
      local score2 = b2 + torch.dot(example.X[sampleIndex], w2)
      local score3 = b3 + torch.dot(example.X[sampleIndex], w3)
      local normalizer = math.exp(score1) + math.exp(score2) + math.exp(score3)
      local prob1 = math.exp(score1) / normalizer
      local prob2 = math.exp(score2) / normalizer
      local prob3 = math.exp(score3) / normalizer
      vp(2, string.format('probs for sample %d: %f %f %f', sampleIndex, prob1, prob2, prob3))
      local logProb = nil
      local y = example.y[sampleIndex]
      if  y == 1 then
         logProb = math.log(prob1)
      elseif y == 2 then
         logProb = math.log(prob2)
      elseif  y == 3 then
         logProb = math.log(prob3)
      else
         error(string.format('bad y (%d)', y))
      end
      local lossSample = - logProb  -- unweighted, unregularized
      return lossSample * example.s[sampleIndex] + example.lambda * sumSquaredWeights(example)
   end

   local function expectedLossOnSample1(example)
      local firstMethodLoss = expectedLossOnSample1FirstMethod(example)
      local secondMethodLoss = expectedLossOnSample(example, 1)
      assertEq(firstMethodLoss, secondMethodLoss, .0001)
      return secondMethodLoss
   end

   local function expectedLossOnSample2(example)
      return expectedLossOnSample(example, 2)
   end

   -- main function starts here

   local vp = makeVp(0, 'makeKnownExample')

   -- supply default arg
   lambdaValue = lambdaValue or .01  -- supply default value
   
   local example = makeExample()
   example.sumSquaredWeights = sumSquaredWeights(example)
   local expectedLossSample1 = expectedLossOnSample1(example)
   local expectedLossSample2 = expectedLossOnSample2(example)
   vp(2, 'expected loss on sample 1', expectedLossSample1,
         'expected loss on sample 2', expectedLossSample2)
   example.expectedLossOnBatch = (expectedLossSample1 + expectedLossSample2) / 2

   return example
end

-------------------------------------------------------------------------------      
-- TEST  PRIVATE METHODS 
-------------------------------------------------------------------------------

-- Test the form of the returned values.
-- The value of the returned values is tested in the tests of methods (below).
local function _gradientLossLogprobabilities_test(example)
   local vp = makeVp(0, '_gradientLossLogprobabilities_test')
   
   local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, example.lambda)

   local initialTheta = of:initialTheta()
   local gradient, loss, logProbabilities = of:_gradientLossLogprobabilities(initialTheta)
   vp(2, 'loss', loss, 'logPredictions', logProbabilities)
   assert(gradient:nDimension() == 1)
   assert(gradient:size(1) == initialTheta:size(1))

   assert(type(loss) == 'number')
   assert(loss >= 0)
   
   assert(logProbabilities:nDimension() == 2)
   assert(logProbabilities:size(1) == example.nSamples)
   assert(logProbabilities:size(2) == example.nClasses)

   -- assert that sum(exp(logPredictions) == 1) and that each exp(logPrediction) is a probability
   local predictions = torch.exp(logProbabilities)
   vp(2, 'predictions', predictions)
   vp(2, 'example', example)
   for sampleIndex = 1, example.nSamples do
      for classIndex = 1, example.nClasses do
         local prediction = predictions[sampleIndex][classIndex]
         vp(2, 'prediction', prediction)
         assert(prediction >= 0)
         assert(prediction <= 1)
      end
      local sum = torch.sum(predictions[sampleIndex])
      vp(2, 'sum', sum, 'preditions[sampleIndex]', predictions[sampleIndex])
      assertEq(sum, 1.0, 0.001)  -- NOTE: the tolerance is needed; it cannot be too big
   end
end

_gradientLossLogprobabilities_test(makeRandomExample())
_gradientLossLogprobabilities_test(makeKnownExample())
   
-------------------------------------------------------------------------------
-- TEST PUBLIC METHODS
-------------------------------------------------------------------------------

-- test method initialTheta
local function initialTheta_test(example)
   local vp = makeVp(0, 'initialTheta_test')
   local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, example.lambda)
   local initialTheta = of:initialTheta()
   vp(2, 'initialTheta', initialTheta)

   assert(initialTheta:nDimension() == 1)
   assert(initialTheta:size(1) == (example.nClasses) * (example.nFeatures + 1))
end

initialTheta_test(makeRandomExample())
initialTheta_test(makeKnownExample())

-------------------------------------------------------------------------------

-- test method loss before testing gradient method
-- because the test of the gradient method depends on the loss method working
local function loss_test(lambda, makeExampleFunction)
   local vp = makeVp(0, 'loss_test')
   vp(1, 'lambda', lambda, 'makeExampleFunction', makeExampleFunction)

   local example = makeExampleFunction(lambda)
   local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, lambda)

   -- test on the batch (which is all of the samples)
   local theta = example.theta 
   local loss = of:loss(theta)

   -- test the loss, which may or may not have an expected value
   assert(type(loss) == 'number')
   assert(loss >= 0)
   if example.expectedLossOnBatch then
      vp(2, 'loss', loss, 'expected loss', example.expectedLossOnBatch)
      assertEq(loss,  example.expectedLossOnBatch, .0001)
   end
end

-- test on example with known loss
loss_test(0, makeKnownExample)   -- first with no regularizer
loss_test(.01, makeKnownExample)  -- then with regularizer

-- test on example random example (for which we don't precompute the expected loss)
loss_test(.01, makeRandomExample) 

-------------------------------------------------------------------------------

-- make sure that public method gradient and private method _lossGradient return the same value
-- do this because the test of the gradient value relies on calling the private method
local function gradient_test_returns_same(lambda)
   local vp = makeVp(0, 'gradient_test_returns_same')
   local example = makeKnownExample(lambda)
   local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, example.lambda)
   local theta = of:initialTheta()  -- use random theta

   local nTests = 10
   for test = 1, nTests do
      local randomTheta = torch.rand(theta:size(1))

      local gradientFromPublicMethod = of:gradient(randomTheta)
      vp(2, 'gradientFromPublicMethod', gradientFromPublicMethod)

      local gradientFromPrivateMethod = of:_gradientLossLogprobabilities(randomTheta)
      vp(2, 'gradientFromPrivateMethod', gradientFromPrivateMethod)

      assertEq(gradientFromPublicMethod, gradientFromPrivateMethod, .0001)
   end
end

local function gradient_test_gradient_value(lambda)   
   -- make sure the gradient value returned by the private method _lossGradient is correct
   -- call the private method so that the index of the sample to use can be specified
   local vp = makeVp(0, 'gradient_test_gradient_value')

   local function test(makeExampleFunction, lambda)
      local vp = makeVp(0, 'gradient_test_gradient_value::test')
      vp(1, 'makeExampleFunction', makeExampleFunction, 'lambda', lambda)
      local example = makeExampleFunction(lambda)
      local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, example.lambda)
      local sampleIndex = 1

      local function f(theta)
         vp(3,'theta in f', theta)
         local loss = of:loss(theta)
         return loss
      end

      local gradient = of:gradient(example.theta)

      local eps = 1e-5
      local eps = .0001  -- just for testing
      local fdGradient = finiteDifferenceGradient(f, example.theta, eps)
      for i = 1, example.theta:size(1) do
         vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, gradient[i], i, fdGradient[i]))
      end
      assertEq(gradient, fdGradient, .0001)
   end
   
   test(makeKnownExample, lambda)
   local nRandomTests = 10
   for i = 1, nRandomTests do 
      test(makeRandomExample, lambda)
   end
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

-------------------------------------------------------------------------------

local function assertProbabilityVector(v)
   assert(v:nDimension() == 1)
   local sumV = 0
   for i = 1, v:size(1) do 
      local p = v[i]
      assert(p >= 0)
      assert(p <= 1)
      sumV = sumV + p
   end
   assertEq(sumV, 1, .0001)
end

local function assertAllEqual(v)
   local first = v[1]
   for i = 2, v:size(1) do
      assertEq(first, v[i], .0001)
   end
end

local function predict_test()
   local vp = makeVp(0, 'testPredict')
   local lambda = 0
   local example = makeRandomExample(lambda)
   local of = ObjectivefunctionLogregNnbatch(example.X, example.y, example.s, example.nClasses, example.lambda)
   local theta = of:initialTheta()

   local newX = torch.rand(10, example.nFeatures)
   local probabilities = of:predictions(newX, theta)
   vp(2, 'probabilities', probabilities)
   assert(probabilities:nDimension() == 2)
   assert(probabilities:size(1) == example.nSamples)
   assert(probabilities:size(2) == example.nClasses)
   for s = 1, example.nSamples do
      assertProbabilityVector(probabilities[s])
   end

   -- test with known probabilities
   local newX = torch.rand(10, example.nFeatures)
   local theta = theta:zero() -- all zeroes ==> probabilities are equal
   local probabilities = of:predictions(newX, theta)
   vp(2, 'probabilities', probabilities)
   assert(probabilities:nDimension() == 2)
   assert(probabilities:size(1) == example.nSamples)
   assert(probabilities:size(2) == example.nClasses)
   for s = 1, example.nSamples do
      assertProbabilityVector(probabilities[s])
      assertAllEqual(probabilities[s])
   end
end

predict_test()

print('ok ObjectivefunctionLogregNnbatch')
