-- ModelLogregregression_test1.lua
-- regression test on problem similar to example problem
--
-- Since the theta values is selected randomly as are the X values,
-- the probabilities will be about equal, so the y choices
-- are roughly random. Thus fitting a model accurately will be
-- impossible.
--
-- Hence check only that the iterations converge. And don't bother
-- to generate the y values from a known theta value.

require 'ConfusionMatrix'
require 'ifelse'
require 'makeVp'
require 'ModelLogreg'
require 'printTableVariable'
require 'Random'

torch.manualSeed(123)

-- create random data about the same size as the problem of most interest
-- RETURNS
-- X, y, s, nCLasses : synthetic data
-- actualTheta       : actual parameters used to generate y from X
local function makeData()
   local vp, verboseLevel = makeVp(2, 'makeTrainingData')
   local nSamples = 60  
   local nFeatures = 8
   local nClasses = 14
   
   if false then
      nSamples = 5
      nFeatures = 3
      nClasses = 3
   end

   local X = torch.rand(nSamples, nFeatures)
   local y = Random():integer(nSamples, 1, nClasses)
   local s = torch.abs(Random():uniform(nSamples, 0, 1))

   return {X = X, y = y, s = s, nClasses = nClasses, nSamples = nSamples}
end

local function makeModel(data)
   local model = ModelLogreg(data.X, data.y, data.s, data.nClasses)
   return model
end

local function fitModelBottouEpoch(model, toleranceLoss, printLoss, initialStepSize)
   local vp = makeVp(1, 'fitModelBottouEpoch')
   vp(1, 'model', model)
   assert(model)
   assert(printLoss ~= nil)

   local function nextStepSizes(currentStepSize)
      return {currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local stepSizes = {}
   local lastStepSize = 0
   local function callback(lossBeforeStep, nextTheta, stepSize)
      if lastStepSize ~= stepSize then
         table.insert(stepSizes, stepSize)
      end
      lastStepSize = stepSize
   end

   local fittingOptions = {
      method = 'bottou',
      sampling = 'epoch',
      methodOptions = {
         printLoss = printLoss,
         initialStepSize = initialStepSize,
         nEpochsBeforeAdjustingStepSize = 20,
         nEpochsToAdjustStepSize = 2,
         nextStepSizes = nextStepSizes
      },
      samplingOptions = {},
      convergence = {
         maxEpochs = 900,
         toleranceLoss = toleranceLoss
      },
      regularizer = {L2 = 0.001}
   }
   local optimalTheta, fitInfo = model:fit(fittingOptions)

   print(string.format('there are %d stepSizes', #stepSizes))
   for _, stepSize in ipairs(stepSizes) do
      print(stepSize)
   end

   return optimalTheta, fitInfo
end

local function fitModelGradientDescent(model, toleranceLoss, printLoss, initialStepSize)
   local vp = makeVp(1, 'fitModelGradientDescent')
   vp(1, 'model', model)
   assert(model)
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
      maxEpochs = 9800,  -- with stepsize 1(?), at 9897 epochs, the loss increases, probably because of numeric rounding
      maxEpochs = 50000,
      maxEpochs = 19000, -- with stepsize 0.5, at 19786 epochs, the loss increases
      toleranceLoss = toleranceLoss,
      toleranceTheta = nil}
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
   local function test(algo, initialStepSize)
      local vp = makeVp(2, 'test')
      assert(algo)
      assert(initialStepSize)

      local toleranceLoss = 1e-5
      local toleranceLoss = 1e-6
      local toleranceLoss = 1e-7
      local toleranceLoss = 1e-8
      local toleranceLoss = nil   

      local data = makeData()
      vp(2, 'data', data)
      printTableValue('data', data)
      assert(type(data) == 'table')

      local model = makeModel(data)
      vp(2, 'model', model)
      assert(model ~= nil)

      vp(2, 'algo', algo)
      local optimalTheta, fitInfo = fitModel(model, algo, toleranceLoss, initialStepSize)
      assert(optimalTheta:nDimension() == 1)

      local convergedReason = fitInfo.convergedReason
      vp(2,'convergedReason', convergedReason)
      assert(convergedReason == 'maxEpochs')

      local probabilities, predictInfo = model:predict(data.X, optimalTheta)
      assert(probabilities:nDimension() == 2)
      assert(probabilities:size(1) == data.nSamples)
      assert(probabilities:size(2) == data.nClasses)

      local predictedClasses = predictInfo.mostLikelyClasses
      assert(predictedClasses:nDimension() == 1)
      assert(predictedClasses:size(1) == data.nSamples)

      local errorRate = makeErrorRate(data.y, predictedClasses)
      local expectedErrorRate = .80
      vp(2, 'errorRate', errorRate, 'expectedErrorRate', expectedErrorRate)
      assert(errorRate <= expectedErrorRate)

      testResult = {
         convergedReason = fitInfo.convergedReason
         ,finalLoss = fitInfo.finalLoss
         ,nEpochsUntilConvergence = fitInfo.nEpochsUntilConvergence
         ,errorRate = errorRate
      }
      return testResult
   end

   local function initialStepSizeFunction(algo)
      return ifelse(algo == 'bottouEpoch', 1, .5)
   end
   
   local algos = {'bottouEpoch', 'gradientDescent'}
   local algos = {'bottouEpoch'}  -- for now, ModelLogreg implements just this one
   
   local testResults = {}
   for _, algo in ipairs(algos) do
      local testId = {algo = algo}
      local initialStepSize = initialStepSizeFunction(algo)
      assert(initialStepSize)
      testResults[testId] = test(algo, initialStepSize)
   end
   
   for caseId, testResult in pairs(testResults) do
      print()
      printTableValue('caseId', caseId)
      printTableValue('testResult', testResult)
   end
end

testEverything()

print('ok ModelLogreg regression test 1')
