-- OpfuncLogreg_timing_comparisons.lua
-- compare timing for concrete classes implementing abstract class OpfuncLogreg
-- only test the method :lossGradient(), because it is typically in the inner loop of models

require 'assertEq'
require 'makeVp'
require 'OpfuncLogregMurphyBatch'
require 'OpfuncLogregNnBatch'
require 'OpfuncLogregNnOne'
require 'printVariable'
require 'printAllVariables'
require 'printTableVariable'
require 'Random'
require 'Timer'
require 'torch'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')


-- TIMING TEST; USE REALISTIC SET OF PARAMETERS

-- control parameters for all timing tests

local nIterations = 100
local nIterations = 10
--local nIterations = 10000  -- for final timing comparisons

-- setup timing test example


local function makeTimingExample()
   local timingExample = {
      nFeatures = 8,
      nSamples = 60,
      nClasses = 14,
      lambda = .001
   }
   timingExample.X = torch.rand(timingExample.nSamples, timingExample.nFeatures)
   timingExample.y = Random:integer(timingExample.nSamples, 1, timingExample.nClasses)
   timingExample.s = Random:uniform(timingExample.nSamples, 0.001, 1)
   return timingExample
end


-- timing test: overall

local function timingComparisons(nIterations)
   local vp = makeVp(1, 'timingComparisons')
   local timingExample = makeTimingExample()

   local ofMurphyBatch = OpfuncLogregMurphyBatch(timingExample.X, 
                                                 timingExample.y, 
                                                 timingExample.s, 
                                                 timingExample.nClasses, 
                                                 timingExample.lambda)
   local thetaMurphyBatch = ofMurphyBatch:initialTheta() 

   local ofNnBatch = OpfuncLogregNnBatch(timingExample.X,
                                         timingExample.y,
                                         timingExample.s,
                                         timingExample.nClasses,
                                         timingExample.lambda)
   local thetaNnBatch = ofNnBatch:initialTheta()
                                                
   local ofNnOne = OpfuncLogregNnOne(timingExample.X, 
                                     timingExample.y, 
                                     timingExample.s, 
                                     timingExample.nClasses, 
                                     timingExample.lambda)
   local thetaNnOne = ofNnOne:initialTheta() 


   local timer = Timer()
   local cpuTimes = {}

   local function accumulateTime(implementationName)
      local soFar = cpuTimes[implementationName] or 0
      cpuTimes[implementationName] = timer:cpu() + soFar
      timer:reset()
   end

   for iteration = 1, nIterations do
      -- MurphyBatch: each gradient uses the entire epoch (the batch)
      local loss, gradient = ofMurphyBatch:lossGradient(thetaMurphyBatch)
      accumulateTime('MurphyBatch')

      -- NnBatch: each gradient uses the entire epoch (the batch)
      local loss, gradient = ofNnBatch:lossGradient(thetaNnBatch)
      accumulateTime('NnBatch')

      -- NnOne: each gradient uses a randomly-chosen sample, so iterate over the epoch
      for sampleIndex = 1, timingExample.nSamples do
         local loss, gradient = ofNnOne:lossGradient(thetaNnOne)
      end
      accumulateTime('NnOne')
   end


   vp(1, string.format('Timing results for OpfuncLogreg concrete implementations using %d iterations',
                       nIterations))
   for implementationName, cpuTime in pairs(cpuTimes) do
      vp(1, string.format('implementation %15s avg CPU/iteration %f',
                          implementationName, cpuTime/nIterations))
   end
end


local nIterations = 1000
print(string.format('starting timing comparisons for %d iterations', nIterations))
timingComparisons(nIterations)
   
print('finished OpfuncLogreg concrete implementations timing comparisons')
