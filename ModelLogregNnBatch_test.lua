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
local function makeTrainingData(useSaliences, size)
   local nSamples = 60
   local nFeatures = 8
   local nClasses = 14
   if size == 'small' then
      nSamples = 5
      nFeatures = 2
      nClasses = 3
      print('using small sample size')
   end

   local lambda = 0       -- arbitrary value needed for APIs

   -- randomly generate data
   local X = torch.rand(nSamples, nFeatures)
   local y = Random():integer(nSamples, 1, nClasses)  -- class numbers are fixed up below
   local s 
   if useSaliences then
      s = torch.abs(torch.rand(nSamples)) -- saliences must be non-negative
   else
      s = torch.Tensor(nSamples):zero()
   end

   -- get random weights from the corresponding optimization function
   local opfunc = OpfuncLogregNnBatch(X, y, s, nClasses, 0)
   local actualTheta = opfunc:initialTheta()

   return X, y, s, nClasses, actualTheta
end

-- return model and X and y values for it
local function makeModel(useSaliences, lambda)
   local X, y, s, nClasses, actualTheta = makeTrainingData(useSaliences)

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
   local useSaliences = true
   local lambda = 0.0001
   local model = makeModel(useSaliences, lambda)
   assert(model ~= nil)
end

testConstruction()

-------------------------------------------------------------------------------
-- test method fit
-------------------------------------------------------------------------------

local function fitModel(model, toleranceLoss)
   local vp = makeVp(1, 'fitModel')
   vp(1, 'model', model)

   toleranceLoss = toleranceLoss or .001

   local function nextStepSizes(currentStepSize)
      return {currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local fittingOptions = {
      method = 'bottouEpoch',
      printLoss = true,
      initialStepSize = 1,
      nEpochsBeforeAdjustingStepSize = 1,
      nEpochsToAdjustStepSize = 2,
      nextStepSizes = nextStepSizes,
      nSteps = 2,    
      maxEpochs = 100,
      toleranceLoss = toleranceLoss,
      toleranceTheta = .01}
   local fitInfo = model:fit(fittingOptions)
   return fitInfo
end

local function testFitInfo(fitInfo)
   local vp = makeVp(2, 'testFitInfo')
   assert(type(fitInfo) == 'table')
   vp(2, 'convergedReason', fitInfo.convergedReason)
   vp(2, 'finalLoss', fitInfo.finalLoss)
   vp(2, 'nEpochsUntilConvergence', fitInfo.nEpochsUntilConvergence)
   vp(2, 'optimalTheta size', fitInfo.optimalTheta:size())
   -- MAYBE: Figure out some real tests
end

local function testFit()
   local vp = makeVp(2, 'testFit')
   local useSaliences = true
   local lambda = 0.0001
   local model = makeModel(useSaliences, lambda)
   local fitInfo = fitModel(model)
   testFitInfo(fitInfo)
end

testFit()

-------------------------------------------------------------------------------
-- test method predict
-------------------------------------------------------------------------------

local function testPredictValues(useSaliences, lambda, toleranceLoss)
   local vp = makeVp(1, 'testPredictValues')
   local model, actualX, actualY = makeModel(useSaliences, lambda)
   local fitInfo = fitModel(model, toleranceLoss)

   -- predict each X used as training data
   local predictedY, predictInfo = model:predict(actualX, fitInfo.optimalTheta)
   vp(2, 'predictedY', predictedY)
   printTableVariable('model')
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
      vp(1, string.format('i %d actualY %f predictedY %f', i, actual, predicted))
      if actual ~= predicted then
         nErrors = nErrors + 1
      end
   end
   vp(1, 'fraction errors', nErrors / model.nSamples)
   stop()
end

testPredictValues(false, 0.0001, .00001)  -- no saliences, regularized
testPredictValues(true, 0.0001)  -- use saliences, regularized

print('ok ModelLogregNnBatch')
