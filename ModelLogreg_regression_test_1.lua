-- ModelLogregregression_test1.lua
-- test on known problem
-- this is a port of logisticRegression_rtest1.lua to the ModelLogreg class
-- TODO: test on weighted training points

require 'ifelse'
require 'makeVp'
require 'ModelLogregNnBatch'
require 'printTableVariable'

torch.manualSeed(123)

local function makeY(X)
   local x1 = X[1]
   local x2 = X[2]

   local y = ifelse(x1 < 0.5,
                    ifelse(x2 < 0.5, 1, 2),
                    ifelse(x2 < 0.5, 3, 4))
   return y
end

local function makeData(equalSaliences)
   local nSamples = 100
   local nFeatures = 2
   local X = torch.rand(nSamples, nFeatures)

   local nClasses = 4
   local y = torch.Tensor(nSamples)
   for i = 1, nSamples do
      y[i] = makeY(X[i])
   end
   
   local s = torch.Tensor(nSamples):fill(1)
   if not equalSaliences then
      error('not yet implemented')
   end

   return nClasses, X, y, s
end

local function trainModel(nClasses, X, y, s)
   local vp = makeVp(2, 'trainModel')
   local lambda = 0.001
   
   local model = ModelLogregNnBatch(X, y, s, nClasses, lambda)
   
   local function nextStepSizes(currentStepSize)
      return {currentStepSize, .5 * currentStepSize, 1.5 * currentStepSize}
   end

   local fittingOptions = { -- for method bottouEpoch
      initialStepSize = 1,
      method = 'bottouEpoch',
      nEpochsBeforeAdjustingStepSize = 3,
      nEpochsToAdjustStepSize = 1,
      nextStepSizes = nextStepSizes,
      maxEpochs = 100,
      toleranceLoss = 1e-6,
      printLoss = true
   }

   local fittingOptions = { -- for method gradientDescent
      initialStepSize = 1,
      method = 'gradientDescent',
      maxEpochs = 1000,
      toleranceLoss = 1e-4,
      printLoss = true
   }

   local optimalTheta, fitInfo = model:fit(fittingOptions)
   assert(optimalTheta)
   printTableVariable('fitInfo')
   assert(fitInfo.convergedReason == 'toleranceLoss')
   
   return optimalTheta, model
end
   
local function predict(optimalTheta, model, newX)
   local probabilities, predictInfo = model:predict(newX, optimalTheta)
   return predictInfo.mostLikelyClasses
end

local function calculateErrorRate(actual, predicted, printErrors)
   local nSamples = actual:size(1)
   assert(predicted:size(1) == nSamples)

   local nErrors = 0
   for i = 1, nSamples do
      if actual[i] ~= predicted[i] then
         nErrors = nErrors + 1
         if printErrors then
            print(string.format('sample %d actual %d predicted %d', i, actual[i], predicted[i]))
         end
      end
   end
   return nErrors / nSamples
end

local function test(equalSaliences)
   local nClasses, X, y, s = makeData(equalSaliences)
   local optimalTheta, model = trainModel(nClasses, X, y, s)
   assert(optimalTheta)
   assert(model)
   local predictions = predict(optimalTheta, model, X)  -- predict the training samples
   
   local errorRate = calculateErrorRate(y, predictions)
   print(string.format('use saliences %s errorRate %f', tostring(equalSaliences), errorRate))
   assert(errorRate < .05)
end

test(true)   -- all saliences equal
test(false)  -- some training samples are more important than others

print('ok ModelLogreg_regression_test1')
