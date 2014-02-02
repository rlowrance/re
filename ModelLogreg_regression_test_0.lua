-- ModelLogreg_regression_test_1.lua
-- regression test
-- four classes that are very close together, so expect a non-zero error rate
-- Yann advises that a better test would be to have a clear separation so that the 
-- error rate would be expected to be zero.
-- My decision is to implement both test cases:
-- - test case A: classes are very close together
-- - test case B: classes are very separated

require 'ConfusionMatrix'
require 'ModelLogreg'
require 'makeVp'
require 'ObjectivefunctionLogregNnbatch'
require 'printAllVariables'
require 'printTableVariable'
require 'printVariable'
require 'Random'
require 'torch'

torch.manualSeed(123)


local function makeData(caseName)
   local nClasses = 4
   local nSamplesPerClass = 25
   local nSamples = nSamplesPerClass * nClasses
   local X = torch.Tensor(nSamples, 2)
   local y = torch.Tensor(nSamples)
   local s = torch.Tensor(nSamples):fill(1)   -- all salience are equal
   
   -- mutate X and y by appending randomly-generated samples
   local nextSampleIndex = 0
   local random = Random()
   local function appendSamples(lowerLeft, upperRight, label)

      local function randomIn(lowest, highest)
         local vector = random:uniform(1, lowest, highest) -- generate 1 sample
         return vector[1]
      end

      local function appendSample()
         local x1 = randomIn(lowerLeft[1], upperRight[1])
         local x2 = randomIn(lowerLeft[2], upperRight[2])
         nextSampleIndex = nextSampleIndex + 1
         X[nextSampleIndex][1] = x1
         X[nextSampleIndex][2] = x2
         y[nextSampleIndex] = label
      end
      for i = 1, nSamplesPerClass do
         appendSample()
      end
   end

   if caseName == 'close together' then
      appendSamples({0,0}, {1,1}, 1)
      appendSamples({0,1}, {1,2}, 2)
      appendSamples({1,0}, {2,1}, 3)
      appendSamples({1,1}, {2,2}, 4)
   elseif caseName == 'far apart' then
      appendSamples({0,0}, {1,1}, 1)
      appendSamples({0,10}, {1,11}, 2)
      appendSamples({10,0}, {10,1}, 3)
      appendSamples({10,10}, {10,11}, 4)
   end

   return {X = X, y = y, s = s, nSamples = nSamples, nClasses = nClasses}
end

local function makeModel(data)
   local model = ModelLogreg(data.X, data.y, data.s, data.nClasses)
   return model
end

-- return optimalTheta, fitInfo
local function fitModelBottouEpoch(model, toleranceLoss, printLoss, initialStepSize)
   local vp = makeVp(1, 'fitModelBottouEpoch')
   vp(1, 'model', model)
   assert(model)
   assert(toleranceLoss)
   assert(printLoss ~= nil)

   local function nextStepSizes(currentStepSize)
      return {currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local lossBeforeStep = math.huge
   local function callback(lossBeforeStep, nextTheta)
      assert(lossBeforeStep < previousLoss)
      assert(nextTheta:nDimension(1) == 1)

      previousLoss = lossBeforeStep
   end

   local fittingOptions = {
      method = 'bottou',
      sampling = 'epoch',
      methodOptions = {printLoss = printLoss,
                       initialStepSize = initialStepSize,
                       nEpochsBeforeAdjustingStepSize = 20,
                       nEpochsToAdjustStepSize = 2,
                       nextStepSizes = nextStepSizes},
      samplingOptions = {},
      convergence = {maxEpochs = 1000,
                     toleranceLoss = toleranceLoss,
                     toleranceTheta = .01},
      regularizer = {L2 = 0}
   }
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   return optimalTheta, fitInfo
end

local function fitModelGradientDescent(model, toleranceLoss, printLoss, initialStepSize)
   local vp = makeVp(1, 'fitModelGradientDescent')
   vp(1, 'model', model)
   assert(model)
   assert(toleranceLoss)
   assert(printLoss ~= nil)
   assert(initialStepSize)

   local lossBeforeStep = math.huge
   local function callback(lossBeforeStep, nextTheta)
      assert(lossBeforeStep < previousLoss)
      assert(nextTheta:nDimension(1) == 1)

      previousLoss = lossBeforeStep
   end

   local fittingOptions = {
      method = 'gradientDescent',
      callBackEndOfEpoch = callback,
      printLoss = printLoss,
      initialStepSize = initialStepSize,
      maxEpochs = 1000,
      toleranceLoss = toleranceLoss,
      toleranceTheta = .01}
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   return optimalTheta, fitInfo
end

local function fitModel(model, algo, toleranceLoss, initialStepSize)
   assert(initialStepSize)
   local printLoss = true
   if algo == 'bottouEpoch' then
      return fitModelBottouEpoch(model, toleranceLoss, printLoss, initialStepSize)
   else
      return fitModelGradientDescent(model, toleranceLoss, printLoss, initialStepSize)
   end
end

local function makeErrorRate(actualY, predictedY)
   local cm = ConfusionMatrix()
   for i = 1, actualY:size(1) do
      cm:add(actualY[i], predictedY[i])
   end
   return cm:errorRate()
end

local function testEverything()

   -- return a testResult
   local function test(algo, dataset, initialStepSize)
      local vp = makeVp(2, 'test')
      assert(algo)
      assert(dataset)
      assert(initialStepSize)

      local toleranceLoss = 1e-5
      local toleranceLoss = 1e-6

      local data = makeData(dataset.name)
      vp(2, 'data', data)
      assert(type(data) == 'table')

      local model = makeModel(data)
      vp(2, 'model', model)
      assert(model ~= nil)

      vp(2, 'dataset.name', dataset.name, 'algo', algo)
      assert(initialStepSize)
      local optimalTheta, fitInfo = fitModel(model, algo, toleranceLoss, initialStepSize)
      assert(optimalTheta:nDimension() == 1)

      local convergedReason = fitInfo.convergedReason
      vp(2,'convergedReason', convergedReason)
      assert(convergedReason ~= 'maxEpochs')

      local probabilities, fitInfo = model:predict(data.X, optimalTheta)
      assert(probabilities:nDimension() == 2)
      assert(probabilities:size(1) == data.nSamples)
      assert(probabilities:size(2) == data.nClasses)

      local predictedClasses = fitInfo.mostLikelyClasses
      assert(predictedClasses:nDimension() == 1)
      assert(predictedClasses:size(1) == data.nSamples)

      local errorRate = makeErrorRate(data.y, predictedClasses)
      vp(2, 'errorRate', errorRate, 'expectedErrorRate', dataset.expectedErrorRate)
      assert(errorRate <= dataset.expectedErrorRate)

      testResult = {
         convergedReason = fitInfo.convergedReason
         ,finalLoss = fitInfo.finalLoss
         ,nEpochsUntilConvergence = fitInfo.nEpochsUntilConvergence
         ,errorRate = errorRate
      }
      return testResult
   end

   local function initialStepSizeFunction(datasetName, algo)
      return ifelse(datasetName == 'close together',
                    ifelse(algo == 'bottouEpoch', 1, .5),
                    ifelse(algo == 'bottouEpoch', 1, .05))
   end
   
   local datasets = {
      {name = 'close together', expectedErrorRate = .10}
      ,{name = 'far apart', expectedErrorRate = 0}
   }

   local algos = {'bottouEpoch', 'gradientDescent'}
   local algos = {'bottouEpoch'}  -- for now, ModelLogreg only implements this algo
   
   local testResults = {}
   for _, dataset in ipairs(datasets) do
      for _, algo in ipairs(algos) do
         local testId = {dataset = dataset, algo = algo}
         local initialStepSize = initialStepSizeFunction(dataset.name, algo)
         assert(initialStepSize)
         testResults[testId] = test(algo, dataset, initialStepSize)
      end
   end
   
   for caseId, testResult in pairs(testResults) do
      printTableValue('caseId', caseId)
      printTableValue('testResult', testResult)
      print()
   end
end

testEverything()


print('ok ModelLogreg regression test 0')
