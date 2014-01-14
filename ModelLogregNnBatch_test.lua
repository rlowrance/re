-- LogregWeightedNnBatch_test.lua
-- unit test

require 'LogregWeightedNnBatch'
require 'makeVp'
require 'printAllVariables'
require 'printTableVariable'
require 'printVariable'
require 'Random'

-------------------------------------------------------------------------------
-- make test objects (fixtures in unit test frameworks)
-------------------------------------------------------------------------------

-- create random data about the same size as the problem of most interest
-- RETURNS
-- X, y, s, nCLasses : synthetic data
-- actualTheta       : actual parameters used to generate y from X
local function makeTrainingData(useSaliences)
   local nSamples = 60
   local nFeatures = 8
   local nClasses = 14
   local lambda = 0       -- arbitrary value needed for APIs
   if true then
      nSamples = 5
      nFeatures = 2
      nClasses = 3
      print('revert to 60 samples, 8 features, and 14 classes')
   end

   -- randomly generate data
   local X = torch.rand(nSamples, nFeatures)
   local y = Random():integer(nSamples, 1, nClasses)  -- class numbers are fixed up below
   local s 
   if useSaliences then
      s = torch.abs(torch.rand(nSamples)) -- saliences must be non-negative
   else
      s = torch.Tensor(nSamples):zero()
   end

   -- get random weights from a model
   local opfunc = LogregOpfuncNnBatch(X, y, s, nClasses, 0)
   local actualTheta = opfunc:initialTheta()

      
   -- by hand, fit a model that uses the actual parameters
   local model = LogregWeightedNnBatch(X, y, s, nClasses, lambda)
   --printTableVariable('model')

   local probs, y = model:predict(X, actualTheta) -- predict using training data
   --printVariable('probs') printVariable('y')
   assert(probs:nDimension() == 2)
   assert(probs:size(1) == nSamples)
   assert(probs:size(2) == nClasses)
   assert(y:nDimension() == 1)
   assert(y:size(1) == nSamples)

   return X, y, s, nClasses, actualTheta
end

local function makeModel(useSaliences, lambda)
   local X, y, s, nClasses, actualTheta = makeTrainingData(useSaliences)

   local model = LogregWeightedNnBatch(X, y, s, nClasses, lambda)
   return model
end

-------------------------------------------------------------------------------
-- TEST SOME PRIVATE METHODS
-------------------------------------------------------------------------------

local function test_converged()
   local useSaliences = true
   local lambda = 0.001
   local model = makeMode(useSaliences, lambda)
   
   local nEpochs = 10
   local nextTheta = torch.Tensor(3):fill(1)
   local previousTheta = torch.Tensor(3):fill(3)
   local nextLoss = 5
   local previousLoss = 6

   local function test(fittingOptions)
      return model:_converged(fittingOptions, nEpochs, nextTheta, previousTheta, nextLoss, previousLoss)
   end

   local fittingOptions = {maxEpochs=100}
   assert(test({maxEpochs == 10}))
   assert(not test({maxEpochs == 11}))
   
   error('write more tests')
end

if false then
   test_converged()
else
   print('did not run test_converged')
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

local function testFit()
   local useSaliences = true
   local lambda = 0.0001
   local model = makeModel(useSaliences, lambda)

   local function nextStepSizes(currentStepSize)
      return{currentStepSize, 0.5 * currentStepSize, 1.5 * currentStepSize}
   end

   local fittingOptions = {
      method = 'bottouEpoch',
      initialStepSize = 1,
      nEpochsBeforeAdjustingStepSize = 1,
      nextStepSizes = nextStepSizes,
      nSteps = 2,    
      maxEpochs = 10,
      toleranceLoss = .1,
      toleranceTheta = .1}
   local fitInfo = model:fit(fittingOptions)
   printTableVariable('fitInfo')
   assert(type(fitInfo) == 'table')
   vp(2, 'convergedReason', fitInfo.convergedReason)
   vp(2, 'nEpochsUntilConvergence', fitInfo.nEpochsUntilConvergence)
   vp(2, 'optimalTheta', fitInfo.optimalTheta)
   error('write tests')
end

testFit()

   

-------------------------------------------------------------------------------
-- test method predict
-------------------------------------------------------------------------------

local function testPredictValues(useSaliences, lambda)
   local X, y, s, nClasses, actualTheta = makeTrainingData(useSaliences)

   -- train the model
   local model = LogregWeightedNnBatch(X, y, s, nClasses, lambda)
   local fittingOptions = {
      method = 'bottouEpoch',
      nEpochsBeforeAdjustingStepSize = 2,
      maxEpochs = 100,
      toleranceLoss = 0.001,
      toleranceTheta = 0.01}
   local optimalTheta, fitInfo  = model:fit(fittingOptions)
   vp(2, 'convergedReason', fitInfo.convergedReason)
   vp(2, 'nEpochsUntilConvergence', fitInfo.nEpochsUntilConvergence)
   vp(2, 'optimalTheta', optimalTheta)
   error('write more tests')
   error('test 1D and 2D newX values')
end

testPredictValues(true, 0)  -- use saliences, not regularized
      

error('write some tests')
print('ok LogregWeightedNnBatch')
