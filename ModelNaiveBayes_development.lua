-- ModelNaiveBayes_development.lua.lua
-- figure out how to program Naive Bayes
-- use example from Wikipedia at "Naive Bayes"

require 'assertEq'
require 'ifelse'
require 'isTensor'
require 'makeVp'
require 'ModelNaiveBayes'
require 'printTableValue'

local function makeData()
   local data = {
      isFemale = torch.Tensor{0, 0, 0, 0, 1, 1, 1, 1},
      height = torch.Tensor{6, 5.92, 5.58, 5.92, 5, 5.5, 5.42, 5.75}, -- in feet
      weight = torch.Tensor{180, 190, 170, 165, 100, 150, 130, 150},  -- in pounds
      foot = torch.Tensor{12, 11, 12, 10, 6, 8, 7,9},                 -- inches
   }
   return data
end

-- create new table split, basically a cross tab
-- split.<data feature name>,<target feature value> = Tensor 1D
local function splitByTargetFeatureValue(data, targetFeatureName)
   
   -- return sequence of featureName values for which targetFeatureName == targetFeatureValue
   local function extract(data, targetFeatureName, targetFeatureValue, featureName)
      local vp = makeVp(0, 'extract')
      vp(1, 'targetFeatureValue', targetFeatureValue, 'featureName', featureName)
      local result = {}
      local targetFeatureValues = data[targetFeatureName]
      for i = 1, targetFeatureValues:size(1) do
         if targetFeatureValues[i] == targetFeatureValue then
            table.insert(result, data[featureName][i])
         end
      end
      vp(1, 'result', result)
      return result
   end

   -- BODY
   local vp, verboseLevel = makeVp(0, 'splitByTargetFeatureValue')
   assert(type(data) == 'table')
   assert(type(targetFeatureName) == 'string')
   
   -- build set of target feature values
   local nSamples = data[targetFeatureName]:size(1)
   local targetFeatureValues = {}
   for i = 1, nSamples do
      local targetFeatureValue = data[targetFeatureName][i]
      if not targetFeatureValues[targetFeatureValue] then
         targetFeatureValues[targetFeatureValue] = true
      end
   end
   vp(2, 'targetFeatureValues', targetFeatureValues)
   
   -- split all the features except the target feature
   local split = {}
   for featureName, featureValueTensor in pairs(data) do
      split[featureName] = {}
      for targetFeatureValue, _ in pairs(targetFeatureValues) do
         local seq = extract(data, targetFeatureName, targetFeatureValue, featureName)
         vp(2, 'featureName', featureName, 'targetFeatureValue', targetFeatureValue, 'seq', seq)
         split[featureName][targetFeatureValue] = torch.Tensor(seq)
         if verboseLevel > 1 then printTableValue('split', split) end
      end
   end

   return split
end


-- return table of statistics stats
-- stats.<feature name>.<target value>.mean
-- stats.<feature name>.<target value>.std
local function makeStats(split)

   local function makeFeatureNames(split) 
      local set = {}
      for featureName, _ in pairs(split) do
         set[featureName] = true
      end

      return set
   end

   local function makeTargetValues(split, featureNames)
      for featureName, _ in pairs(featureNames) do
         local set = {}
         for targetValue, _ in pairs(split[featureName]) do
            set[targetValue] = true
         end
         return set  -- the target values are the same for each feature
      end
   end

   local function makeMeanStd(split, featureName, targetValue)
      local tensor = split[featureName][targetValue]
      return {mean = tensor:mean(), std = tensor:std()}
   end


   -- BODY
   local vp = makeVp(2, 'stats')
   vp(1, 'split', split)

   local featureNames = makeFeatureNames(split)  -- a set of strings
   local targetValues = makeTargetValues(split, featureNames)  -- a set of values

   local stats = {}
   for featureName, _ in pairs(featureNames) do
      stats[featureName] = {}
      for targetValue, _ in pairs(targetValues) do
         local meanStd = makeMeanStd(split, featureName, targetValue)
         stats[featureName][targetValue] = meanStd
      end
   end

   return stats
end

-- return table of in-sample probabilities for specified feature
local function inSampleProbabilities(split, featureName)
   
   local counts = {}
   local totalCount = 0
   for targetFeatureValue, sample in pairs(split[featureName]) do
      -- the sample is a Tensor with one element for each observed sample
      local count = sample:size(1)
      totalCount = totalCount + count
      counts[targetFeatureValue] = count
   end
   
   local probabilities = {}
   for targetFeatureValue, _ in pairs(split[featureName]) do
      probabilities[targetFeatureValue] = counts[targetFeatureValue] / totalCount
   end

   return probabilities
end

local function check(split, target, featureName, expectedMean, expectedVariance)
   local targetValue = ifelse(target == 'male', 0, 1)  -- coding for isFemale
   local actualMean = split[featureName][targetValue].mean
   local actualStd = split[featureName][targetValue].std
   
   assertEq(actualMean, expectedMean, .001)
   assertEq(actualStd, math.sqrt(expectedVariance), 001)
end

-- return probability density of drawing x from Gaussian with given mean and std
local function gaussian(x, mean, std)
   local vp = makeVp(0, 'guassian')
   vp(1, 'x', x, 'mean', mean, 'std', std)
   local variance = std * std
   local coefficient = 1 / math.sqrt(2 * math.pi * variance)
   local difference = x - mean
   local term = (- difference * difference) / (2 * variance)
   local pd = coefficient * math.exp(term)
   vp(2, 'variance', variance, 'coefficient', coefficient, 'difference', difference, 'term', term)
   vp(1, 'pd', pd)
   return pd
end

local function guassianTest()
   local actual = gaussian(6, 5.855, math.sqrt(3.5033e-2))  -- from Wikipedia article
   local expected = 1.5789
   assertEq(actual, expected, .001)
end
guassianTest()

-- return probabilities table for newX having each targetValue
-- result.<targetValue> = <probability density that newX has targetValue>
-- use Gaussian distribution
-- for now, don't use Laplace smoothing
local function predict(stats, targetFeatureName, priors, newX)

   -- return set
   local function makeTargetValues(stats, targetFeatureName)
      local set = {}
      for targetValue, _ in pairs(stats[targetFeatureName]) do
         set[targetValue] = true
      end
      return set
   end

   local function getFeatureProbability(stats, featureName, featureValue, targetValue)
      return gaussian(featureValue, stats[featureName][targetValue].mean, stats[featureName][targetValue].std)
   end

   local function makeUnnormalizedProbability(targetValue, stats, priors, newX)
      local vp = makeVp(0,' makeUnnormalizedProbability')
      vp(1, 'targetValue', targetValue)
      local p = priors[targetValue]
      vp(2, 'p', p)
      for featureName, featureValue in pairs(newX) do
         local pFeature = getFeatureProbability(stats, featureName, featureValue, targetValue)
         vp(2, 'featureName', featureName, 'pFeature', pFeature)
         p = p * pFeature  -- MAYBE: work in the log domain
      end
      vp(1, 'p', p)
      return p 
   end
     

   local vp = makeVp(0, 'predict')

   local unnormalizedProbability = {}
   local total = 0
   for targetValue, _ in pairs(makeTargetValues(stats, targetFeatureName)) do
      vp(2, 'targetValue', targetValue)
      local up = makeUnnormalizedProbability(targetValue, stats, priors, newX)
      unnormalizedProbability[targetValue] = up
      total = total + up
   end
   vp(2, 'unnormalizedProbability', unnormalizedProbability, 'total', total)

   -- NOTE: in production code, can use the unnormalized probabilities
   local probabilities = {}
   for featureName, unnormalized in pairs(unnormalizedProbability) do
      probabilities[featureName] = unnormalized / total
   end
   vp(1, 'probabilities', probabilities)
   return probabilities
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

local vp = makeVp(2, 'main program')

local data = makeData()
vp(1, 'data', data)

local split = splitByTargetFeatureValue(data, 'isFemale')
vp(1, 'split', split)

local stats = makeStats(split)
vp(1, 'stats', stats)

-- check calculated stats vs. Wikipedia page
check(stats, 'male', 'height', 5.855, 3.5033e-2) 
check(stats, 'male', 'weight', 176.25, 1.2292e2)
check(stats, 'male', 'foot', 11.25, 9.1667e-1)
check(stats, 'female', 'height', 5.4175, 9.7225e-2)
check(stats, 'female', 'weight', 132.5, 5.5833e2)
check(stats, 'female', 'foot', 7.5, 1.6667e0)
vp(1, 'completed checking')

local priors = inSampleProbabilities(split, 'isFemale')
vp(2, 'priors', priors)

-- classify new sample
local targetFeatureName = 'isFemale'
local newSample = {height = 6, weight = 130, foot = 8}
local probabilities = predict(stats, targetFeatureName, priors, newSample)
vp(1, 'probabilities', probabilities)
assert(probabilities[1] > probabilities[0]) -- person is likely a female

-- rerun example using ModelNaiveBayes

vp(1, '*********************************** rerun using ModelNaiveBayes')

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

print('done')
