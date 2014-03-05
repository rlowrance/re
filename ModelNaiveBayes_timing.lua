-- ModelNaiveBayes.timing
-- assess timing for practical example

require 'assertEq'
require 'ifelse'
require 'isTensor'
require 'makeVp'
require 'ModelNaiveBayes'
require 'printTableValue'
require 'Random'
require 'time'
require 'Timer'

local function makeData(nClasses, nFeatures, nSamples)
   local vp = makeVp(1, 'makeData')
   vp(1, 'nClasses', nClasses, 'nFeatures', nFeatures, 'nSample', nSamples)
   return {
      nClasses = nClasses,
      nFeatures = nFeatures,
      nSamples = nSamples,
      X = torch.rand(nSamples, nFeatures),
      y = Random():integer(nSamples, 1, nClasses)
   }
end

-- return
-- errorRate : number
-- timings   : table where key = construct/fit/predict, value = {cpu, wallclock} seconds
local function fitAndTest(data, newX, expectedTargets)
   local function addTimings(timings, what, cpu, wallclock)
      timings[what] = {cpu = cpu, wallclock = wallclock}
   end

   local function construct(data)
      return ModelNaiveBayes(data.X, data.y, data.nClasses)
   end

   local function fit(model, fittingOptions)
      return model:fit(fittingOptions)
   end

   local function predict(model, newX, optimalTheta)
      return model:predict(newX, optimalTheta)
   end

   local vp = makeVp(2, 'fitAndTest')
   vp(1, 'data', data, 'newX', newX, 'expectedTargets', expectedTargets)

   local timings = {}

   local cpu, wallclock, model = time('both', construct, data)
   addTimings(timings, 'constrcut', cpu, wallclock)

   local fittingOptions = {
      method = 'gaussian',
   }
   local cpu, wallclock, optimalTheta, fitInfo = time('both', fit, model, fittingOptions)
   addTimings(timings, 'fit', cpu, wallclock)

   local cpu, wallclock, predictions, predictInfo = time('both', predict, model, newX, optimalTheta)
   addTimings(timings, 'predict', cpu, wallclock)

   local isError = torch.ne(data.y, expectedTargets)
   local errorRate = isError:sum() / newX:size(1)
   vp(1, 'errorRate', errorRate)

   return errorRate, timings
end

local function runTimedTest(nClasses, nFeatures, nSamplesTest, nSamplesTrain)
   local dataTrain = makeData(nClasses, nFeatures, nSamplesTrain)
   local dataTest = makeData(nClasses, nFeatures, nSamplesTest)
   local errorRate, timings = fitAndTest(dataTrain, dataTest.X, dataTrain.y)

   print('errorRate', errorRate)
   printTableValue('timings', timings)
end

local function runSmallTest()
   local nClasses = 2
   local nFeatures = 3
   local nSamplesTest = 5
   local nSamplesTrain = 10

   runTimedTest(nClasses, nFeatures, nSamplesTest, nSamplesTrain)
end

local function runLargeTest()
   -- size test to HEATING.CODE imputation problem size
   local vp = makeVp(2, 'runLargeTest')
   local nClasses = 14
   local nFeatures = 8
   local nSamplesTest = 218051
   local nSamplesTrain = 656479  
   vp(2, 'nClasses', nClasses, 'nFeatures', nFeatures, 'nSamplesTest', nSamplesTest, 'nSamplesTrain', nSamplesTrain)

   runTimedTest(nClasses, nFeatures, nSamplesTest, nSamplesTrain)
end

-- MAIN PROGRAM

local vp = makeVp(2, 'tester')

if false then
   runSmallTest()
end

if true then
   print('starting large test')
   runLargeTest()
end


print('done')
