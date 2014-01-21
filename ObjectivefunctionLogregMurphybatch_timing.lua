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


-- TIMING TEST; USE REALISTIC SET OF PARAMETERS

-- control parameters for all timing tests

local nIterations = 100
local nIterations = 10
--local nIterations = 10000  -- for final timing comparisons

-- setup timing test example


local function makeOfFromTimingExample()
   local timingExample = {
      nFeatures = 8,
      nSamples = 60,
      nClasses = 14,
      L2 = .001
   }
   timingExample.X = torch.rand(timingExample.nSamples, timingExample.nFeatures)
   timingExample.y = Random:integer(timingExample.nSamples, 1, timingExample.nClasses)
   timingExample.s = Random:uniform(timingExample.nSamples, 0.001, 1)
   local of = ObjectivefunctionLogregMurphybatch(timingExample.X, 
                                     timingExample.y, 
                                     timingExample.s, 
                                     timingExample.nClasses, 
                                     timingExample.L2)
   return of, timingExample
end

-- running the Lua profiler causes assert statements to be triggered that are not 
-- triggered when the profiler is turned off. This suggests a bug in the Lua
-- profiler. Hence the complicated code below to explicitly time functions.

--profiler.start('/tmp/profiler.txt')


-- timing test: overall

local function timingOverall(nIterations)
   local vp = makeVp(1, 'timingOverall')
   local of = makeOfFromTimingExample()
   
   local theta = of:initialTheta()
   local timer = Timer()
   for i = 1, nIterations do
      local loss, gradient = of:lossGradient(theta)
   end
   vp(1, string.format('timingOverall %d iterations avg cpu/iteration %f',
                       nIterations, timer:cpu() / nIterations))
end


if true then
   print(string.format('starting Timing test timingOverall with %d iterations', nIterations))
   local nIterations = 100
   timingOverall(nIterations)
else
   print('you skipped timingOverall')
end

-- _scores
local function timingScoresImplementations(nIterations)
   local nImplementations = 2

   local of = makeOfFromTimingExample()
   local theta = of:initialTheta()
   local thetaInfo = of:_loss_structureTheta(theta)
   
   -- make sure each implementation returns the same result (scores)
   local scores = {}
   for implementation = 1, nImplementations do
      scores[implementation] = of:_loss_scores(thetaInfo, implementation)
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
         local scores = of:_loss_scores(thetaInfo, implementation)
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

if true then
   print(string.format('starting Timing test timingScoresImplementations with %d iterations', nIterations))
   timingScoresImplementations(nIterations)
else
   print('you skipped timingScoresImplemenations')
end


-- gradient
local function timingGradientLogLikelihoodImplementations(nIterations)
   local vp = makeVp(0, 'timingGradientLogLikelihoodImplementations')
   print('running timing for _gradientLogLiklihood implementations')
   local nImplementations = 4
   print(string.format('nIterations = %d nImplementations = %d', nIterations, nImplementations))

   local of, timingExample = makeOfFromTimingExample()
   local theta = of:initialTheta()
   local loss, lossInfo = of:_lossLossinfoProbabilities(theta)
   local nSamples = timingExample.nSamples

   -- make sure each implemenation returns the same result
   local gradients = {}
   local sampleIndex = 1
   for implementation = 1, nImplementations do
      local g = of:_gradient_logLikelihood(lossInfo, implementation)
      --vp(2, 'g', g)
      assert(g:nDimension() == 1)
      gradients[implementation] = g 
      vp(2, string.format('implementation %d has %d elements', 
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
            local gradient = of:_gradient_logLikelihood(lossInfo, implementation)
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
else
   print('you skipped timingGradientLogLikelihoodImplemenations')
end


-- each private method when called as part of a call to of:loss then of:gradient

-- the calls to of:loss and of:gradient are unrolled in the code below
local function timingPrivateMethods(nIterations)
   local vp = makeVp(1, 'timingPrivateMethods')
   local of, timingExample = makeOfFromTimingExample()
   
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
   local loss, lossInfo = of:_lossLossinfoProbabilities(theta)  -- lossInfo is need later
   local nSamples = timingExample.nSamples
   local L2 = timingExample.L2

   timerOverall = Timer()
   timer:reset()
   for i = 1, nIterations do
      -- unroll the function calls in the loss function
      local thetaInfo = of:_loss_structureTheta(theta)
      accumulateTime('_loss_structureTheta')

      local scores = of:_loss_scores(thetaInfo)
      accumulateTime('_loss_scores')

      local probabilities = of:_loss_probabilities(scores)
      accumulateTime('_loss_probabilities')

      local logLikelihood = of:_loss_logLikelihood(probabilities)
      accumulateTime('_loss_logLikelihood')

      local regularizer = of:_loss_regularizer(thetaInfo)
      accumulateTime('_loss_regularizer')

      -- unroll the function calls in gradient function
      local gradientLogLikelihood = of:_gradient_logLikelihood(lossInfo)
      accumulateTime('_gradient_logLikelihood')

      local gradientRegularizer = of:_gradient_regularizer(lossInfo)
      accumulateTime('_gradient_regularizer')
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
   
print('ok ObjectivefunctionLogregMurphybatch_timing')
