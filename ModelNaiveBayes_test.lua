-- ModelNaiveBayes_test.lua
-- unit test

require 'assertEq'
require 'ifelse'
require 'isTensor'
require 'makeVp'
require 'ModelNaiveBayes'
require 'printTableValue'

-- data are from Wikipedia at Naive Bayes Classifier
local function makeData()
   local data = {
      isFemale = torch.Tensor{0, 0, 0, 0, 1, 1, 1, 1},
      height = torch.Tensor{6, 5.92, 5.58, 5.92, 5, 5.5, 5.42, 5.75}, -- in feet
      weight = torch.Tensor{180, 190, 170, 165, 100, 150, 130, 150},  -- in pounds
      foot = torch.Tensor{12, 11, 12, 10, 6, 8, 7,9},                 -- inches
   }
   return data
end

-- return X 2D Tensor and sequence of feature names (int -> string)
local function makeX(data)
   local nSamples = data.foot:size(1)
   local nFeatures = 3
   local X = torch.Tensor(nSamples, nFeatures)
   for i = 1, nSamples do
      X[i][1] = data.foot[i]
      X[i][2] = data.height[i]
      X[i][3] = data.weight[i]
   end
   return X, {'foot', 'height', 'weight'}
end

-- return y 1D Tensor and sequence of codes used (int -> string)
local function makeY(data)
   local nSamples = data.foot:size(1)
   local y = torch.Tensor(nSamples)
   for i = 1, nSamples do
      y[i] = ifelse(data.isFemale[i] == 1, 1, 2)
   end
   return y, {"female", "male"}
end
   
         
-- MAIN PROGRAM

local vp, verboseLevel = makeVp(2, 'tester')

local data = makeData()
local X, featureNames = makeX(data)
local nFeatures = #featureNames

local y, codes = makeY(data)
local nClasses = #codes

vp(1, 'featureNames', featureNames, 'codes', codes, 'nFeatures', nFeatures, 'nClasses', nClasses)

vp(1, 'X', X)
vp(1, 'y', y)

local model = ModelNaiveBayes(X, y, nClasses)
vp(1, 'model', model)

local fittingOptions = {method = 'gaussian'}
local optimalTheta, fitInfo = model:fit(fittingOptions)
vp(1, 'optimalTheta', optimalTheta, 'fitInfo', fitInfo)

-- print the optimalTheta info for diagnostic purposes
vp(1, 'optimalTheta')
for c = 1, nClasses do
   for j = 1, nFeatures do
      local mean = optimalTheta.means[c][j]
      local std = optimalTheta.stds[c][j]
      vp(1, string.format('class %s feature %s mean %f std %f var %f', codes[c], featureNames[j], mean, std, std * std))
   end
   vp(1, string.format('class %s probability %f', codes[c], optimalTheta.targetProbabilities[c]))
end

local newX = torch.Tensor{{8, 6, 130}}  -- foot, height, weight (abc order)
local predictions, predictInfo = model:predict(newX, optimalTheta)
vp(1, 'predictions', predictions, 'predictInfo', predictInfo, '.mostLikelyClasses', predictInfo.mostLikelyClasses)
for i = 1, newX:size(1) do
   for c = 1, nClasses do
      vp(1, string.format('test sample %d probability of %s = %6.4f', i, codes[c], predictions[i][c]))
   end
end

assert(predictions[1][1] > predictions[1][2])  -- is female
assert(predictInfo.mostLikelyClasses[1] == 1)

-- another use case: one of the classes is not in the training data
local data = makeData()
local X, feauresNames = makeX(data)
local nSamples = X:size(1)
local y, codes = makeY(data)
local nClasses = #codes

-- change every occurence of class 1 to class 2
for i = 1, nSamples do
   if y[i] == 1 then
      y[i] = 2
   end
end
vp(2, 'y', y)

-- fit the model that is missing class 1 in the training data
local model = ModelNaiveBayes(X, y, nClasses)
local fittingOptions = {method = 'gaussian'}
local optimalTheta, fitInfo = model:fit(fittingOptions)
local predictions, predictInfo = model:predict(X, optimalTheta)  -- predict the training data
if verboseLevel > 1 then
   printTensorValue('predictInfo.mostLikelyClasses', predictInfo.mostLikelyClasses)
end
for i = 1, nSamples do
   assert(predictInfo.mostLikelyClasses[i] == 2)
end

print('ok ModelNaiveBayes')
