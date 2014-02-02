-- ModelLogreg_regression_test_2.lua
-- the test was originally at www.ats.ucla.edu/stat/r/dae/mlogit.htm
-- but that page has been replaced by a new page with a different worked example

require 'argmax'
require 'ConfusionMatrix'
require 'makeVp'
require 'ModelLogregNnbatch'
require 'NamedMatrix'
require 'printTableValueFields'
require 'printTableVariable'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')

local function readData()
   local vp, verboseLevel = makeVp(1, 'readData')
   local nm = NamedMatrix.readCsv{
      file='ModelLogreg_regression_test_2_data.csv'
      ,numberColumns = {'num', 'brand', 'female', 'age'}
   }

   if verboseLevel > 0 then
      -- print names
      local names = nm.names
      for i, name in ipairs(names) do
         print('name ' .. name)
      end
      
      -- print first few rows
      local heading = ''
      for c = 1, 4 do
         heading = heading ..  string.format('%6s ', names[c])
      end
      print(heading)
      for i = 1, 6 do
         local detail = ''
         for c = 1, 4 do 
            detail = detail .. string.format('%6d ', nm.t[i][c])
         end
         print(detail)
      end
   end

   return nm
end


-- return uncentered data: X, y, s, nClasses, XColumns (table: k = feature name, v = column number)
local function makeTrainingSamples(namedMatrix)
   local vp, verboseLevel = makeVp(2, 'makeXysnClasses')
   vp(1, 'namedMatrix', namedMatrix)
   
   local nSamples = namedMatrix.t:size(1)
   local X = torch.Tensor(nSamples, 2)
   local y = torch.Tensor(nSamples)
   local s = torch.Tensor(nSamples)

   local cIndexAge = namedMatrix:columnIndex('age')
   local cIndexBrand = namedMatrix:columnIndex('brand')
   local cIndexFemale = namedMatrix:columnIndex('female')
   vp(2, 'cIndexAge', cIndexAge, 'cIndexBrand', cIndexBrand, 'cIndexFemale', cIndexFemale)
   vp(2, 'namedMatrix.t size', namedMatrix.t:size())

   local XColumns = {
      female = 1,
      age = 2}

   -- populate results variable from input NamedMatrix
   for i = 1, nSamples do
      X[i][XColumns.female] = namedMatrix.t[i][cIndexFemale]  -- isFemale
      X[i][XColumns.age] = namedMatrix.t[i][cIndexAge]        -- age
      
      y[i] = namedMatrix.t[i][cIndexBrand]                    -- brand
      s[i] = 1                                                -- salience
   end

   if verboseLevel > 0 then
      print('first 6 rows in VW format')
      print('brand | isFemale age')
      for i = 1, 6 do
         local s = string.format('%d | ', y[i])
         for f = 1, 2 do
            s = s .. string.format('%d ', X[i][f])
         end
         print(s)
      end
   end

   local nClasses = torch.max(y)
   vp(1, 'nClasses', nClasses)
   return X, y, s, nClasses, XColumns
end

local function makeModel(X, y, s, nClasses)
   local vp = makeVp(1, 'makeModel')
   vp(1, 'X', X)
   local L2 = 0.001
   local L2 = 0
   print('model not regularized')
   local model = ModelLogregNnbatch(X, y, s, nClasses, L2)

   return model
end

local function fitModelGradientDescent(model)
   local toleranceLoss = 1e-5
   -- toleranceLoss = 1e-5 ==> loss = 1.083 after 10,000 steps, and tolerance not achieved

   -- for initialStepSize 1 e-3:
   --   initial loss is 6.23
   --   which is reduced to 1.10 via stepsize 1e-3
   local fittingOptions = {
      method = 'gradientDescent'
      ,initialStepSize = 1e-3  -- larger initial steps lead to an increase in the loss
      ,maxEpochs = 10000
      ,toleranceLoss = toleranceLoss
      ,printLoss = true
   }
   
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   assert(fitInfo.convergedReason == 'toleranceLoss')
   return optimalTheta, fitInfo, toleranceLoss
end

local function fitModelBottouEpoch(model)
   local function nextStepSizesFunction(currentStepSize)
      return {currentStepSize, currentStepSize * .5, currentStepSize * 1.5}
   end

   local toleranceLoss = 1e-6
   --local toleranceLoss = 1e-7
   --local toleranceLoss = 1e-8       
   --local toleranceLoss = 1e-9


   local fittingOptions = {
      method = 'bottouEpoch'
      ,initialStepSize = .001
      ,nEpochsBeforeAdjustingStepSize = 10
      ,nEpochsToAdjustStepSize = 1
      ,nextStepSizes = nextStepSizesFunction
      ,maxEpochs = 1000
      -- :w
      -- ,maxEpochs = 10000  -- test only
      ,toleranceLoss = toleranceLoss
      ,printLoss = true
   }
   
   local optimalTheta, fitInfo = model:fit(fittingOptions)
   assert(fitInfo.convergedReason == 'toleranceLoss', 'hit maxEpochs, not toleranceLoss')
   return optimalTheta, fitInfo, toleranceLoss
end

-- return probabilities, fitInfo
local function fitModel(model, algo)
   return fitModelBottouEpoch(model)
end

local function predict(model, newX, theta)
   return  model:predict(newX, theta)
end


local function makeConfusionMatrix(actuals, predictions)
   local vp = makeVp(0, 'makeConfusionMatrix')
   vp(1, 'actuals', actuals, 'predictions', predictions)
   local cm = ConfusionMatrix()
   for i = 1, actuals:size(1) do
      cm:add(actuals[i], predictions[i])
   end
   return cm
end

local function determineErrorRate(actuals, predictions)
   local vp = makeVp(0, 'determineErrorRate')
   local cm = makeConfusionMatrix(actuals, predictions)
   return cm:errorRate()
end

local function ranges(X, y, XColumns)
   local vp = makeVp(2, 'ranges')
   assert(XColumns)
   
   local female = X:select(2, XColumns.female)
   local age = X:select(2, XColumns.age)

   return torch.max(age),
          torch.min(age),
          torch.max(y),
          torch.min(y),
          torch.max(female),
          torch.min(female)
end

local function determineActualProbabilities(X, y, female, age, XColumns)
   local vp, verboseLevel = makeVp(0, 'determineActualProbabilites')
   assert(XColumns)
   --vp(1, 'X', X)
   vp(1, 'female', female, 'age', age)
   local counts = {}
   for brand = 1, 3 do
      counts[brand] = 0
   end
   local totalCounts = 0
   for i = 1, X:size(1) do
      local X_female = X[i][XColumns.female]
      local X_age = X[i][XColumns.age]
      if X_female == female and X_age == age then
         local brand = y[i]
         vp(2, 'brand', brand)
         counts[brand] = counts[brand] + 1
         totalCounts = totalCounts + 1
      end
   end
   vp(2, 'totalCounts', totalCounts)
   if verboseLevel > 1 then 
      printTableVariable('counts')
   end

   local probabilities = nil
   if totalCounts > 0 then
      probabilities = torch.Tensor({counts[1] / totalCounts,
      counts[2] / totalCounts,
      counts[3] / totalCounts})
   else
      probabilities = torch.Tensor({0, 0, 0})
   end
   vp(1, 'probabilities', probabilities)
   return probabilities
end


local function determineModelProbabilities(female, age, model, optimalTheta, XColumns)
   local vp = makeVp(0, 'determineModelProbabilities')
   vp(1, 'female', female, 'age', age)
   assert(XColumns)
   local newX = torch.Tensor(1, 2)
   newX[1][XColumns.female] = female
   newX[1][XColumns.age] = age

   local probabilities2D, predictInfo = model:predict(newX, optimalTheta)
   assert(probabilities2D:size(1) == 1)
   local probabilities = probabilities2D[1]
   vp(1, 'probabilities', probabilities)
   return probabilities
end


local function determineTextProbabilities(female, age)
   local vp = makeVp(0, 'deteremineTextProbabilities')
   vp(1, 'age', age, 'female', female)
   -- calculate logits
   local logit1 = 0
   local logit2 = -11.774655 + 0.523814 * female + 0.368206 * age
   local logit3 = -22.721396 + 0.465941 * female + 0.685908 * age

   -- calculate unnormalized probabilities
   local uprob1 = math.exp(logit1)
   local uprob2 = math.exp(logit2)
   local uprob3 = math.exp(logit3)

   -- normalize to get probabilities
   local z = uprob1 + uprob2 + uprob3
   assert(z)
   local prob1 = uprob1 / z
   local prob2 = uprob2 / z
   local prob3 = uprob3 / z
   if female == 0 and age == 24 then
      -- test value from github
      assertEq(prob1, .948, .001)
      assertEq(prob2, .050, .001)
      assertEq(prob3, .002, .001)
   end
   
   local probabilities = torch.Tensor({prob1, prob2, prob3})
   vp(1, 'probabilities', probabilities)
   return probabilities
end

local function printHeader()
   print('          |actual probs     |text probs       |model probs      |best')
   print('female age|brnd1 brnd2 brnd3|brnd1 brnd2 brnd3|brnd1 brnd2 brnd3|a t m')
end

local function printRow(female, age, actualProbabilities, textProbabilities, modelProbabilities)
   local vp = makeVp(0, 'printRow')
   vp(1, 'female', female, 'age', age)
   assert(female) 
   assert(age)
   assert(actualProbabilities)
   assert(textProbabilities)
   assert(modelProbabilities)
   
   local function stringFor(v)
      local vp = makeVp(0, 'stringFor')
      vp(1, 'v', v)
      local result = string.format('%5.3f %5.3f %5.3f', v[1], v[2], v[3])
      vp(1, 'result', result)
      return result
   end

   vp(2, 'actualProbabilities', actualProbabilities)
   vp(2, 'argmax(actualProbabilities)', argmax(actualProbabilities))
   vp(2, 'argmax(textProbabilities)', argmax(textProbabilities))
   vp(2, 'argmax(modelProbabilities)', argmax(modelProbabilities))
   local s = string.format('%6d %3d|%s|%s|%s|%d %d %d',
                           female,
                           age,
                           stringFor(actualProbabilities),
                           stringFor(textProbabilities),
                           stringFor(modelProbabilities),
                           argmax(actualProbabilities),
                           argmax(textProbabilities),
                           argmax(modelProbabilities))
   print(s)
end


local function compareToText(X, y, model, optimalTheta, XColumns)
   local vp = makeVp(1, 'compareToText')
   assert(XColumns)
   local nSamples = X:size(1)
   local maxAge, minAge, maxBrand, minBrand, maxFemale, minFemale = ranges(X, y, XColumns)

   vp(2, 'maxAge', maxAge, 'minAge', minAge)
   vp(2, 'maxBrand', maxBrand, 'minBrand', minBrand)
   vp(2, 'maxFemale', maxFemale, 'minFemale', minFemale)
   
   local nErrors = 0
   local nExamples = 0
   printHeader()
   for female = minFemale, maxFemale do
      for age = minAge, maxAge do
         local actualProbabilities = determineActualProbabilities(X, y, female, age, XColumns)
         local textProbabilities = determineTextProbabilities(female, age)
         local modelProbabilities = determineModelProbabilities(female, age, model, optimalTheta, XColumns)
         printRow(female, age, actualProbabilities, textProbabilities, modelProbabilities)
         local textPrediction = argmax(textProbabilities)
         local modelPrediction = argmax(modelProbabilities)
         if textPrediction ~= modelPrediction then
            nErrors = nErrors + 1
         end
         nExamples = nExamples + 1
      end
   end
   vp(1, 'nErrors', nErrors)
   return nErrors, nExamples
end

local function printHead(tensor)
   for i = 1, 6 do
      print(tensor[i])
   end
end
      

-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local namedMatrix = readData()
local X, y, s, nClasses, XColumns = makeTrainingSamples(namedMatrix)
-- XColumns.featureName = index in X of that feature's column

-- make model
local model = makeModel(X, y, s, nClasses)

-- fit model
local algo = 'BottouEpoch'
local optimalTheta, fitInfo, toleranceLoss = fitModel(model, algo)
printTableValueFields('fitInfo', fitInfo, {'convergedReason', 'finalLoss', 'nEpochsUntilConvergence'})
vp(2, 'fit toleranceLoss', toleranceLoss)

-- predict over the range of relevant female and age features
local females = {0, 1}
local ages = {24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38}

local nSamples = #females * #ages
local newX = torch.Tensor(nSamples, 2)
local newXIndex = 0
for _, female in ipairs(females) do
   for _, age in ipairs(ages) do
      newXIndex = newXIndex + 1
      newX[newXIndex][XColumns.female] = female
      newX[newXIndex][XColumns.age] = age
   end
end

local predictedProbabilities, predictInfo = model:predict(newX, optimalTheta)
print('preditedProbabilities head')
printHead(predictedProbabilities)
stop()

local errorRate = determineErrorRate(y, predictInfo.mostLikelyClasses)
vp(1, 'errorRate on training data', errorRate)

local nErrors, nExamples = compareToText(X, y, model, optimalTheta, XColumns)
print('toleranceLoss = ' .. tostring(toleranceLoss))
print('finalLoss = ' .. tostring(fitInfo.finalLoss))
print('errorRate = ' .. tostring(errorRate))
assert(nErrors == 0, string.format('made %d errors vs. text out of %d examples', nErrors, nExamples))

print('ok ModelLogreg_regression_test_2')

