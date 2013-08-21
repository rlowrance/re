-- modelLogreg_rtest3.lua

require 'makeVp'
require 'modelLogreg'

local verbose = 0
local vp = makeVp(verbose, 'tester')

torch.manualSeed(123456)

local function makeData(nObservationsPerClass, weights)
   local nClasses = 10
   local nObservations = nObservationsPerClass * nClasses
   local nDimensions = 2
   local X = torch.Tensor(nObservations, 2)
   local y = torch.Tensor(nObservations, 1)
   local w = torch.Tensor(nObservations, 1)

   local sd = .5  -- standard deviation of noise around each point
   local index = 0
   for c = 1, nClasses do
      -- generate a cluster centered at (c,c)
      for i = 1, nObservationsPerClass do
         index = index + 1
         X[index][1] = c + torch.normal(0, sd)
         X[index][2] = c + torch.normal(0, sd)
         y[index][1] = c
         if weights == 'uniform' then
            w[index][1] = 1
         elseif weights == 'class' then
            w[index][1] = c
         else
            error('bad weights == ' .. tostring(weights))
         end
      end
   end
   local config = {nClasses=nClasses, 
                   nDimensions=2, 
                   checkArgs=true, 
                   verbose=verbose, 
                   tolerance=1e-2}
   return X, y, w, config
end

local function run(lambda, weights, nObservationsPerClass)
   -- for weights == 'uniform' / 'class'
   --local nObservationsPerClass = 10 -- accuracy = 0.10 / 0.10
   --local nObservationsPerClass = 30 -- accuracy = 0.647 / 0.873
   --local nObservationsPerClass = 100  -- accuracy = 0.847 / 0.869
   local X, y, w, config = makeData(nObservationsPerClass, weights)
   config.verbose = 0
   local thetaStar = modelLogreg.fit(config, X, y, w, lambda)
   local predictions = modelLogreg.predict(config, thetaStar, X)
   
   local nCorrect = 0
   for i = 1, X:size(1) do
      local error = ''
      if predictions[i][1] == y[i][1] then
         nCorrect = nCorrect + 1
      else
         error = 'error'
      end
      print(
         string.format('i %3d x %6.2f %6.2f w %2d actual %d prediction %d %s',
                       i, 
                       X[i][1], X[i][2], 
                       w[i][1],
                       y[i][1], predictions[i][1], 
                       error))
   end

   local accuracy = nCorrect / X:size(1)
   print(string.format('for lambda %f weights %s, accuracy is %f', 
         lambda, weights, accuracy))
   return accuracy
end

local nObservationsPerClassList = {10, 30, 100}
local lambda = 0
for index = 1, 3 do
   local nObservationsPerClass = nObservationsPerClassList[index]
   local accuracyUniform = run(lambda, 'uniform', nObservationsPerClass)
   local accuracyClass = run(lambda, 'class', nObservationsPerClass)
   vp(0, 'accuracyUniform', accuracyUniform)
   vp(0, 'accuracyClass', accuracyClass)
   assert(accuracyUniform <= accuracyClass)
end
--local accuracyUniform = run(0, 'uniform')
--local accuracyClass = run(0, 'class')
--run(.01, 'uniform')
--run(.03, 'uniform')

print('ok modelLogreg_rest3')