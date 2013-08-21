-- modelLogreg_rtest2.lua

require 'ifelse'
require 'makeVp'
require 'modelLogreg'

local verbose = 2
local vp = makeVp(verbose, 'tester')

torch.manualSeed(123)

-- generate data
local nObservations = 100
local X = torch.Tensor(nObservations, 1)
local y = torch.Tensor(nObservations, 1)
local wEqual = torch.Tensor(nObservations, 1)
local wFavorOne = torch.Tensor(nObservations, 1)
local favorOne = 10

local class = 2
for i = 1, nObservations do
   class = class + 1
   if class > 2 then class = 1 end
   y[i][1] = class
   wEqual[i][1] = 1
   wFavorOne[i][1] = ifelse(class == 1, favorOne, 1)
   X[i][1] = class + torch.normal(0, 1)
end

local function run(weights)
   local model = modelLogreg
   local config = {nClasses=2, nDimensions=1, verbose=verbose, checkArgs=true}
   config.verbose = 0
   local lambda = 0
   local thetaStar = model.fit(config, X, y, weights, lambda)
   local predictions = model.predict(config, thetaStar, X)
   
   local nErrors = 0
   for i = 1, nObservations do
      local error = ''
      if predictions[i][1] ~= y[i][1] then 
      error = 'error' 
      nErrors = nErrors + 1
      end
      print(string.format('i %2d x %6.2f y %d predicted %d %s',
                          i, X[i][1], y[i][1], predictions[i][1], error))
   end
   
   local accuracy = (nObservations - nErrors) / nObservations
   print('accuracy = ' .. tostring(accuracy))

   -- probabilities for various X values
   local nObservations = 50
   local NewX = torch.Tensor(nObservations, 1)
   local x = -1
   for i = 1, nObservations do
      NewX[i][1] = x
      x = x + 0.1
   end
   local predictions, probs = model.predict(config, thetaStar, NewX)
   for i = 1, nObservations do
      print(string.format('x %6.2f y %d prob==1 %6.2f',
                          NewX[i][1], predictions[i][1], probs[i][1]))
   end
   
   return accuracy, NewX, probs
end

local accuracyEqual, NewX, probsEqual = run(wEqual)
print('accuracy for equal weights = ' .. tostring(accuracyEqual))

local accuracyFavorOne, _, probsFavorOne = run(wFavorOne)
print('accuracy for favoring class one = ' .. tostring(accuracyFavorOne))

-- compare predictions grids
for i = 1, probsEqual:size(1) do
   print(string.format('x %6.2f prob equal %5.2f prob favor one %5.2f',
                       NewX[i][1], probsEqual[i][1], probsFavorOne[i][1]))
   assert(probsFavorOne[i][1] >= probsEqual[i][1])
end

print('ok modelLogreg_rtest2')