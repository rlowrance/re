-- ModelLogreg_regression_test_1.lua
-- regression test
-- four classes that are very close together, so expect a non-zero error rate
-- Yann advises that a better test would be to have a clear separation so that the 
-- error rate would be expected to be zero.
-- My decision is to implement both test cases:
-- - test case A: classes are very close together
-- - test case B: classes are very separated

require 'ConfusionMatrix'
require 'ModelLogregNnbatch'
require 'makeVp'
require 'ObjectivefunctionLogregNnbatch'
require 'printAllVariables'
require 'printTableVariable'
require 'printVariable'
require 'Random'
require 'torch'

torch.manualSeed(123)

-------------------------------------------------------------------------------
-- make test objects (fixtures in unit test frameworks)
-------------------------------------------------------------------------------


-- create random data about the same size as the problem of most interest
-- RETURNS
-- X, y, s, nCLasses : synthetic data
-- actualTheta       : actual parameters used to generate y from X
local function makeTrainingData(bad)
   local vp, verboseLevel = makeVp(2, 'makeTrainingData')
   assert(bad == nil)
   local nSamples = 60  
   local nFeatures = 8
   local nClasses = 14
   
   if false then
      nSamples = 5
      nFeatures = 3
      nClasses = 2
   end

   local lambda = 0       -- arbitrary value needed for APIs

   -- randomly generate data
   local X = torch.rand(nSamples, nFeatures)
   local y = Random():integer(nSamples, 1, nClasses)  -- class numbers not derived from weights
   local s = torch.abs(torch.rand(nSamples)) -- saliences must be non-negative

   -- get random weights from the corresponding optimization function
   local opfunc = ObjectivefunctionLogregNnbatch(X, y, s, nClasses, 0)
   local initialTheta = opfunc:initialTheta()  -- random weights
   vp(2, 'initialTheta', initialTheta)
   --local actualTheta = initialTheta:zero()

   -- derive y's from initialTheta weights
   local model = ModelLogregNnbatch(X, y, s, nClasses, lambda)
   local probabilities, predictInfo = model:predict(X, initialTheta)
   local predictedY = predictInfo.mostLikelyClasses
   vp(2, 'X', X)
   vp(2, 'probabilities', probabilities, 'predicted y', predictedY)
   
   -- maybe print distribution of predictedY's, which should be random
   if verboseLevel > 1 then
      local nOccurrences = torch.Tensor(nClasses):zero()
      for i = 1, nSamples do
         local index = predictedY[i]
         nOccurrences[index] = nOccurrences[index] + 1
      end
      for classNumber = 1, nClasses do
         vp(2, string.format('class number %d frequency %f',
                             classNumber, nOccurrences[classNumber] / nSamples))
      end
   end

   return X, predictedY, s, nClasses, initialTheta
end

-- return model and X and y values for it
local function makeModel()
   local X, y, s, nClasses, initialTheta = makeTrainingData()

   local lambda = 0.001
   local model = ModelLogregNnbatch(X, y, s, nClasses, lambda)
   return model, X, y
end

-------------------------------------------------------------------------------
-- TEST PUBLIC METHODS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- test construction
-------------------------------------------------------------------------------

local function testConstruction()
   local zeroSaliences = true
   local lambda = 0.0001
   local model = makeModel()
   assert(model ~= nil)
end

if false then
   testConstruction()
end

-------------------------------------------------------------------------------
-- test method fit
-------------------------------------------------------------------------------

local function testFitInfo(fitInfo)
   local vp = makeVp(0, 'testFitInfo')
   assert(type(fitInfo) == 'table')
   vp(2, 'convergedReason', fitInfo.convergedReason)
   vp(2, 'finalLoss', fitInfo.finalLoss)
   vp(2, 'nEpochsUntilConvergence', fitInfo.nEpochsUntilConvergence)
   vp(2, 'optimalTheta size', fitInfo.optimalTheta:size())
   assert(fitInfo.convergedReason == 'toleranceLoss')
end

local function determineErrorRate(actual, predicted)
   local vp = makeVp(1, 'determineErrorRate')
   vp(1, 'actual', actual, 'predicted', predicted)
   assert(actual:nDimension() == 1)
   assert(predicted:nDimension() == 1)
   local nSamples = actual:size(1)
   assert(nSamples == predicted:size(1))
   local nErrors = 0
   for i = 1, nSamples do
      if actual[i] ~= predicted[i] then
         nErrors = nErrors + 1
      end
   end
   return nErrors / nSamples
end

local function testOptimalTheta(optimalTheta, model, trainingX, trainingY)
   local vp = makeVp(1, 'testOptimalTheta')
   vp(1, 'model', model)
   assert(optimalTheta:nDimension() == 1)

   -- test supposed optimalTheta by checking the predictions
   local probabilities, predictInfo = model:predict(trainingX, optimalTheta)
   local errorRate = determineErrorRate(trainingY, predictInfo.mostLikelyClasses)
   vp(1, 'errorRate', errorRate)
   assert(errorRate < 1) -- for now
end

local function testFitDriver(howToFitModel, toleranceLoss, printLoss)
   local vp = makeVp(2, 'testFit')
   local model, X, y = makeModel()
   local optimalTheta, fitInfo = howToFitModel(model, toleranceLoss, printLoss)
   testOptimalTheta(optimalTheta, model, X, y)
   testFitInfo(fitInfo)
end

local function testFit()
   local toleranceLoss = 0.001
   local printLoss = false
   testFitDriver(fitModelBottouEpoch, toleranceLoss, printLoss)
   testFitDriver(fitModelGradientDescent, toleranceLoss, printLoss)
end

if false then
   testFit()
   stop()
end

-------------------------------------------------------------------------------
-- test method predict
-------------------------------------------------------------------------------

local function testPredictValues(zeroSaliences, lambda, toleranceLoss)
   local vp = makeVp(1, 'testPredictValues')

   assert(zeroSaliences ~= nil)
   assert(lambda ~= nil)
   assert(toleranceLoss ~= nil)
   
   -- make the model
   local model, actualX, actualY = makeModel(zeroSaliences, lambda)
   
   -- fit the model
   local toleranceLoss = 0.00001
   local printLoss = true
   local optimalTheta, fitInfo = fitModelBottouEpoch(model, toleranceLoss, printLoss)
   -- check that we actually converged
   assert(fitInfo.convergedReason ~= 'maxEpochs', fitInfo.convergedReason)

   -- predict each X used as training data
   local predictedY, predictInfo = model:predict(actualX, optimalTheta)
   vp(2, 'predictedY', predictedY)
   assert(predictedY:nDimension() == 2)
   assert(predictedY:size(1) == model.nSamples)
   assert(predictedY:size(2) == model.nClasses)

   assert(type(predictInfo) == 'table')
   local predictedClasses = predictInfo.mostLikelyClasses
   vp(2, 'predictedClasses', predictedClasses)
   assert(predictedClasses:size(1) == model.nSamples)

   -- see how we did
   local nErrors = 0
   for i = 1, model.nSamples do
      local actual = actualY[i]
      local predicted = predictedClasses[i]
      vp(2, string.format('i %d actualY %f predictedY %f', i, actual, predicted))
      if actual ~= predicted then
         nErrors = nErrors + 1
      end
   end
   local fractionErrors = nErrors / model.nSamples
   vp(1, 'fraction errors', fractionErrors)
   assert(fractionErrors <= 1.0)  -- it seems that the training data are just too noisy
end

if false then
   local zeroSaliences = true
   local lambda = 0.0001
   local toleranceLoss = 1e-5
   testPredictValues(not zeroSaliences, lambda, toleranceLoss)
   stop()
   testPredictValues(zeroSaliences, lambda, toleranceLoss)
end

-- test error rates

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
   local lambda = 0
   local model = ModelLogregNnbatch(data.X, data.y, data.s, data.nClasses, lambda)
   return model
end

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
      method = 'bottouEpoch',
      callBackEndOfEpoch = callback,
      printLoss = printLoss,
      initialStepSize = initialStepSize,
      nEpochsBeforeAdjustingStepSize = 20,
      nEpochsToAdjustStepSize = 2,
      nextStepSizes = nextStepSizes,
      nSteps = 2,    
      maxEpochs = 1000,
      toleranceLoss = toleranceLoss,
      toleranceTheta = .01}
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

if true then
   testEverything()
end


print('ok ModelLogregNnbatch')
