-- LogregOpfunc_test.lua
-- unit test

require 'assertEq'
require 'finiteDifferenceGradient'
require 'makeVp'
require 'LogregOpfunc'
require 'printVariable'
require 'printAllVariables'
require 'printTableVariable'
require 'profiler'
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

   local of =  LogregOpfunc(testExample.X, 
                            testExample.y, 
                            testExample.s, 
                            testExample.nClasses, 
                            testExample.lambda)
   return of, testExample
end
      
-- test default implementation of private methods

local function _regularizer_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_structureTheta(testExample.theta)
   local regularizer = of:_regularizer(thetaInfo)
   assertEq(regularizer, testExample.expectedRegularizer, .00001)
end

_regularizer_test()

local function _logLikelihood_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_structureTheta(testExample.theta)
   local scores = of:_scores(thetaInfo)
   local probabilities = of:_probabilities(scores)
   local logLikelihood = of:_logLikelihood(probabilities)

   assertEq(logLikelihood, testExample.expectedLogLikelihood, .0001)
end

_logLikelihood_test()

local function _probabilities_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_structureTheta(testExample.theta)
   local scores = of:_scores(thetaInfo)
   local probabilities = of:_probabilities(scores)
   
   assert(probabilities:nDimension() == 2)
   assert(probabilities:size(1) == testExample.nSamples)
   assert(probabilities:size(2) == testExample.nClasses)

   -- expected values computed in octave script LogregOpfunc_test.m
   assertEq(probabilities[1], torch.Tensor{2.2596e-6, 9.9966e-1, 3.3535e-4}, .0001)
   assertEq(probabilities[2], torch.Tensor{4.1397e-8, 9.9995e-1, 4.5398e-5}, .0001)
end

_probabilities_test()

local function _regularizer_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_structureTheta(testExample.theta)
   local regularizer = of:_regularizer(thetaInfo)
   local expectedRegularizer = testExample.theta[2]^2 + testExample.theta[3]^2 +
                               testExample.theta[5]^2 + testExample.theta[6]^2
   assertEq(regularizer, expectedRegularizer, .00001)
   testExample.expectedRegularizer = expectedRegularizer
end

_regularizer_test()


local function _scores_test()
   local of, testExample = makeUnitTestExample()
   local thetaInfo = of:_structureTheta(testExample.theta)
   local biases = thetaInfo.biases
   local weights = thetaInfo.weights
   local scores = of:_scores(thetaInfo)

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



local function _structureTheta_test() 
   local of, testExample = makeUnitTestExample()
   local theta = testExample.theta
   local thetaInfo = of:_structureTheta(theta)
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

_structureTheta_test()


-- test public methods

local function gradient_test(lambda)   
   local vp = makeVp(0, 'gradient_test')
   local of, testExample = makeUnitTestExample()
   testExample.lambda = lambda


   local function f(theta)
      return of:loss(theta)
   end
  
   local loss, lossInfo = of:loss(testExample.theta)
   local gradient = of:gradient(lossInfo)

   local eps = 1e-5
   local fdGradient = finiteDifferenceGradient(f, testExample.theta, eps)
   for i = 1, testExample.theta:size(1) do
      vp(2, string.format('grad[%d] %f fdGrad[%d] %f', i, gradient[i], i, fdGradient[i]))
   end
   assertEq(gradient, fdGradient, .0001)
end

gradient_test(0)  -- first test without the regularizer
gradient_test(.001)  -- now test with the regularizer

local function initialTheta_test()
   local of, testExample = makeUnitTestExample()
   local initialTheta = of:initialTheta()

   assert(initialTheta:nDimension() == 1)
   assert(initialTheta:size(1) == (testExample.nClasses - 1) * (testExample.nFeatures + 1))
end

initialTheta_test()

local function loss_test()
   local of, testExample = makeUnitTestExample()
   local loss = of:loss(testExample.theta)
   local expectedLoss = -testExample.expectedLogLikelihood + 
                        testExample.lambda * testExample.expectedRegularizer

   assertEq(loss, expectedLoss, .0001)
end

loss_test()

-- TIMING TEST; USE REALISTIC SET OF PARAMETERS

-- control parameters for all timing tests

local nIterations = 100
local nIterations = 10
--local nIterations = 10000  -- for final timing comparisons

-- setup timing test example

local timingExample = {
nFeatures = 8,
nSamples = 60,
nClasses = 14,
lambda = .001
}
timingExample.X = torch.rand(timingExample.nSamples, timingExample.nFeatures)
timingExample.y = Random:integer(timingExample.nSamples, 1, timingExample.nClasses)
timingExample.s = Random:uniform(timingExample.nSamples, 0.001, 1)

local function makeOfFromTimingExample()
   return LogregOpfunc(timingExample.X, 
                       timingExample.y, 
                       timingExample.s, 
                       timingExample.nClasses, 
                       timingExample.lambda)
end

-- running the Lua profiler causes assert statements to be triggered that are not 
-- triggered when the profiler is turned off. This suggests a bug in the Lua
-- profiler. Hence the complicated code below to explicitly time functions.

--profiler.start('/tmp/profiler.txt')


-- timing test: overall

local function timingOverall(nIterations)
   local vp = makeVp(1, 'timingOverall')
   local of = makeOfFromTimingExample()
   
   local function lossGradient(theta)
      local loss, lossInfo = of:loss(theta)
      local gradient = of:gradient(lossInfo)
      return loss, gradient
   end

   local theta = of:initialTheta()
   local timer = Timer()
   for i = 1, nIterations do
      local loss, gradient = lossGradient(theta)
   end
   vp(1, string.format('timingOverall %d iterations avg cpu/iteration %f',
                       nIterations, timer:cpu() / nIterations))
end


if true then
   print(string.format('starting Timing test timingOverall with %d iterations', nIterations))
   local nIterations = 100
   timingOverall(nIterations)
   stop()
else
   print('you skipped timingOverall')
end


-- _scores
local function timingScoresImplementations(nIterations)
   local nImplementations = 2

   local of = makeOfFromTimingExample()
   local theta = of:initialTheta()
   local thetaInfo = of:_structureTheta(theta)
   
   -- make sure each implementation returns the same result (scores)
   local scores = {}
   for implementation = 1, nImplementations do
      scores[implementation] = of:_scores(thetaInfo, implementation)
   end
   for implementation = 2, nImplementations do
      assertEq(scores[1], scores[implementation], .0001)
   end

   local timer = Timer()
   local cpuTimes = {}

   local function accumulateTime(implementation)
      local soFar = cpuTimes[implementation] or 0
      cpuTimes[implementation] = timer:cpu() + soFar
      timer:reset()
   end

   for iteration = 1, nIterations do
      for implementation = 1, nImplementations do
         local scores = of:_scores(thetaInfo, implementation)
         accumulateTime(implementation)
      end
   end

   vp(1, string.format('Timing results for _scores implementations using %d iterations',
                       nIterations))
   local cpuImplementation1 = cpuTimes[1] / nIterations
   for implementation = 1, nImplementations do
      local cpuImplementation = cpuTimes[implementation] / nIterations
      vp(1, string.format('implementation %d avg CPU/iteration %f as fraction of 1 %f',
                          implementation, cpuImplementation, cpuImplementation / cpuImplementation1))
   end
end

if false then
   print(string.format('starting Timing test timingScoresImplementations with %d iterations', nIterations))
   timingScoresImplementations(nIterations)
else
   print('you skipped timingScoresImplemenations')
end


-- gradient
local function timingGradientLogLikelihoodImplementations(nIterations)
   local vp = makeVp(2, 'timingGradientLogLikelihoodImplementations')
   print('running timing for _gradientLogLiklihood implementations')
   local nImplementations = 4
   print(string.format('nIterations = %d nImplementations = %d', nIterations, nImplementations))

   local of = makeOfFromTimingExample()
   local theta = of:initialTheta()
   local loss, lossInfo = of:loss(theta)
   local nSamples = timingExample.nSamples

   -- make sure each implemenation returns the same result
   local gradients = {}
   local sampleIndex = 1
   for implementation = 1, nImplementations do
      local g = of:_gradientLogLikelihood(lossInfo, implementation)
      --vp(2, 'g', g)
      assert(g:nDimension() == 1)
      gradients[implementation] = g 
      print(string.format('implementation %d has %d elements', 
                          implementation, 
                          g:size(1)))

   end
   for implementation = 2, nImplementations do
      assertEq(gradients[1], gradients[implementation], .0001)
   end

   local timer = Timer()
   local cpuTimes = {}

   local function accumulateTime(implementation)
      local soFar = cpuTimes[implementation] or 0
      cpuTimes[implementation] = timer:cpu() + soFar
      timer:reset()
   end

   -- run timing experiment on each implementation
   for iteration = 1, nIterations do
      for implementation = 1, nImplementations do
         for sampleIndex = 1, nSamples do
            local gradient = of:_gradientLogLikelihood(lossInfo, implementation)
         end
         accumulateTime(implementation)
      end
   end

   local cpuImplementation1 = cpuTimes[1] / nIterations
   for implementation = 1, nImplementations do
      local cpuImplementation = cpuTimes[implementation] / nIterations
      vp(1, string.format('implementation %d avg CPU/iteration %f as fraction of 1 %f',
                          implementation, cpuImplementation, cpuImplementation / cpuImplementation1))
   end
end

if true then
   print(string.format('starting Timing test timingGradientLogLikelihoodImplemenations with %d iterations', nIterations))
   timingGradientLogLikelihoodImplementations(nIterations)
   stop()
else
   print('you skipped timingGradientLogLikelihoodImplemenations')
end


-- each private method when called as part of a call to of:loss then of:gradient

-- the calls to of:loss and of:gradient are unrolled in the code below
local function timingPrivateMethods(nIterations)
   local vp = makeVp(1, 'timingPrivateMethods')
   local of = makeOfFromTimingExample()
   
   -- apparatus to track accumulated CPU seconds in each method called
   local timer = Timer()
   local cpuTimes = {}

   local function accumulateTime(methodName)
      local soFar = cpuTimes[methodName] or 0
      cpuTimes[methodName] = timer:cpu() + soFar
      timer:reset()
   end

   -- variables needed
   local theta = of:initialTheta()
   local loss, lossInfo = of:loss(theta)  -- info is needed later
   local nSamples = timingExample.nSamples
   local lambda = timingExample.lambda

   timerOverall = Timer()
   timer:reset()
   for i = 1, nIterations do
      -- unroll the function calls in the loss function
      local thetaInfo = of:_structureTheta(theta)
      accumulateTime('_structureTheta')

      local scores = of:_scores(thetaInfo)
      accumulateTime('_scores')

      local probabilities = of:_probabilities(scores)
      accumulateTime('_probabilities')

      local logLikelihood = of:_logLikelihood(probabilities)
      accumulateTime('_logLikelihood')

      local regularizer = of:_regularizer(thetaInfo)
      accumulateTime('_regularizer')

      -- unroll the function calls in gradient function
      local gradientLogLikelihood = of:_gradientLogLikelihood(lossInfo)
      accumulateTime('_gradientLogLikelihood')

      local gradientRegularizer = of:_gradientRegularizer(lossInfo)
      accumulateTime('_gradientRegularizer')
   end

   local overallCpuPerIteration = timerOverall:cpu() / nIterations
   vp(1, string.format('timingPrivateMethodes %d iterations avg cpu/iteration %f',
                       nIterations, overallCpuPerIteration))
   for methodName, cpuSeconds in pairs(cpuTimes) do
      local methodCpuPerIteration = cpuSeconds/nIterations
      local fractionThisMethod = methodCpuPerIteration / overallCpuPerIteration
      vp(1, string.format(' method %30s avgCpu/iteration %f fraction %f', 
                          methodName, methodCpuPerIteration, fractionThisMethod))
   end
end

timingPrivateMethods(nIterations)


   
stop()
print('ok LogregOpfunc')
