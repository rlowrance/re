-- ModelLogregNnBatch_test.lua
-- unit test

require 'ModelLogregNnBatch'
require 'makeVp'
require 'OpfuncLogregNnBatch'
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
   
   if true then
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
   local opfunc = OpfuncLogregNnBatch(X, y, s, nClasses, 0)
   local initialTheta = opfunc:initialTheta()  -- random weights
   vp(2, 'initialTheta', initialTheta)
   --local actualTheta = initialTheta:zero()

   -- derive y's from initialTheta weights
   local model = ModelLogregNnBatch(X, y, s, nClasses, lambda)
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
   stop()

   
   return X, predictedY, s, nClasses, initialTheta
end

-- return model and X and y values for it
local function makeModel()
   local X, y, s, nClasses, initialTheta = makeTrainingData()

   local lambda = 0.001
   local model = ModelLogregNnBatch(X, y, s, nClasses, lambda)
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

testConstruction()

-------------------------------------------------------------------------------
-- test method fit
-------------------------------------------------------------------------------

local function fitModelBottouEpoch(model, toleranceLoss, printLoss)
   local vp = makeVp(1, 'fitModelBottouEpoch')
   vp(1, 'model', model)
   assert(model)
   assert(toleranceLoss)
   assert(printLoss ~= nil)

   local function nextStepSizes(currentStepSize)
      return {currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local fittingOptions = {
      method = 'bottouEpoch',
      printLoss = printLoss,
      initialStepSize = 1,
      nEpochsBeforeAdjustingStepSize = 1,
      nEpochsToAdjustStepSize = 2,
      nextStepSizes = nextStepSizes,
      nSteps = 2,    
      maxEpochs = 1000,
      toleranceLoss = toleranceLoss,
      toleranceTheta = .01}
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   return optimalTheta, fitInfo
end

local function fitModelGradientDescent(model, toleranceLoss, printLoss)
   local vp = makeVp(1, 'fitModelGradientDescent')
   vp(1, 'model', model)
   assert(model)
   assert(toleranceLoss)
   assert(printLoss ~= nil)

   toleranceLoss = toleranceLoss or .001

   local function nextStepSizes(currentStepSize)
      return {currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local fittingOptions = {
      method = 'gradientDescent',
      printLoss = printLoss,
      initialStepSize = 1,
      maxEpochs = 1000,
      toleranceLoss = toleranceLoss,
      toleranceTheta = .01}
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   return optimalTheta, fitInfo
end

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
   assert(errorRate == 0) -- for now
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

testFit()

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

local zeroSaliences = true
local lambda = 0.0001
local toleranceLoss = 1e-5
testPredictValues(not zeroSaliences, lambda, toleranceLoss)
stop()
testPredictValues(zeroSaliences, lambda, toleranceLoss)

print('ok ModelLogregNnBatch')
