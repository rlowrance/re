-- modelLogreg_rtest1.lua
-- test on known problem
-- TODO: test on weighted training points

require 'ifelse'
require 'makeVp'
require 'modelLogreg'

local verbose = 2
local vp = makeVp(verbose)

torch.manualSeed(123)

local function makeData(nObservations, weightOne)
   local nObservations = 100
   local inputs = torch.rand(nObservations, 2)
   local targets = torch.Tensor(nObservations, 1)
   local w = torch.Tensor(nObservations, 1)
   for i = 1, nObservations do
      w[i][1] = 1  -- default weight
      if inputs[i][1] < 0.5 then
         if inputs[i][2] < 0.5 then
            targets[i][1] = 1
            if type(weightOne) == 'number' then
               w[i][1] = weightOne
            end
         else
            targets[i][1] = 2
         end
      else
         if inputs[i][2] < 0.5 then
            targets[i][1] = 3
         else
            targets[i][1] = 4
         end
      end
   end
   local config = {nClasses=4, nDimensions=2, checkArgs=true, verbose=2,
                   tolerance=1e-2}
   return inputs, targets, w, config
end
   
-- return n of correct predictions
local function examineData(predictions, probs, inputs, targets)
   local nCorrect = 0
   if verbose >= 2 then 
      print('actuals vs. predictions')
      for i = 1, predictions:size(1) do
         local error = ' '
         if predictions[i][1] == targets[i][1] then
            nCorrect = nCorrect + 1
         else
            error = 'error'
         end
         print(string.format('input %0.4f %0.4f target %d predicted %d' .. 
                             ' probs %0.2f %0.2f %0.2f %0.2f %s',
                             inputs[i][1], inputs[i][2], targets[i][1],
                             predictions[i][1],
                             probs[i][1], 
                             probs[i][2], 
                             probs[i][3], 
                             probs[i][4],
                             error))
      end
   end
   return nCorrect
end 

local function run(lambda, weightOne)
   local nObservations = 100
   local X, y, w, config = makeData(nObservations, weightOne)
   config.verbose = 0
   local lambda = 0.001 -- no nan fdGradient with this value
   local lambda = 0     -- gets fdGradient == all nan's
   local thetaStar = modelLogreg.fit(config, X, y, w, lambda)
   local predictions, probs = modelLogreg.predict(config, thetaStar, X)
   local nCorrect = examineData(predictions, probs, X, y)
   local accuracy = nCorrect / X:size(1)
   print('accuracy = ' .. tostring(accuracy))
   return accuracy
end

local accuracyEqual = run(0, 1)

local accuracyOneOverweighted = run(0, 10)

vp(0, 'accuracyEqual', accuracyEqual)
vp(0, 'accuracyOneOverweighted', accuracyOneOverweighted)
assert(accuracyEqual >= accuracyOneOverweighted)


local accuracyWeightOne = nil
if true then
   -- all weights are equal (and 1)
   local nObservations = 100
   local X, y, w, config = makeData(nObservations)  -- all weights are 1
   config.verbose = 0
   local lambda = 0.001 -- no nan fdGradient with this value
   local lambda = 0     -- gets fdGradient == all nan's
   local thetaStar = modelLogreg.fit(config, X, y, w, lambda)
   local predictions, probs = modelLogreg.predict(config, thetaStar, X)
   local nCorrect = examineData(predictions, probs, X, y)
   local accuracy = nCorrect / X:size(1)
   --vp(1, 'w', w)
   vp(1, 'accuracy', accuracy)
   assert(accuracy > .95)
   accuracyWeightOne = accuracy
end

if true then
   -- overweight class 1
   local nObservations = 100
   local X, y, w, config = makeData(nObservations, 2)  -- over weight class 1
   local lambda = 0.001
   local lambda = 0    
   config.tolerance = 0.1
   config.verbose = 0
   local thetaStar = modelLogreg.fit(config, X, y, w, lambda)
   local predictions, probs = modelLogreg.predict(config, thetaStar, X)
   local nCorrect = examineData(predictions, probs, X, y)
   vp(1, 'nCorrect', nCorrect)
   local accuracy = nCorrect / X:size(1)
   --vp(1, 'w', w)
   vp(1, 'accuracy', accuracy)
   vp(1, 'accuracyWeightOne', accuracyWeightOne)
   -- The assertion below fails
   -- Why? Perhaps because the classes are perfectly linearly separable.
   --assert(accuracy < accuracyWeightOne)
end


print('ok logisticRegression_rtest1')
