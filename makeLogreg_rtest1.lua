-- makeLogRegImportance_rtest1.lua
-- test on known problem : 4 quadrants
-- TODO: test on weighted training points

require 'assertEq'
require 'checkGradient'
require 'ifelse'
require 'makeLogreg'
require 'maxIndex'
require 'optim_gd'      -- gradient descent
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')
local debugging = false

torch.manualSeed(123)

-- shape of training data
local nClasses = 4
local nDimensions = 2
local nSamplesPerClass = 10
if debugging then
   nSamplesPerClass = 1
end
local nInputs = nClasses * nSamplesPerClass

-- will hold training data
local inputs = torch.Tensor(nInputs, 2)
local targets = torch.Tensor(nInputs)
local importances = torch.Tensor(nInputs)

-- classes are Gausians and these centers
local centers = torch.Tensor{{.25, .25},
                             {.25, .75},
                             {.75, .75},
                             {.75, .25}}
local std = .10
local index = 0

-- importance of class 1 samples is twice the others
local function makeSamples(nSamplesPerClass)
   for j = 1, nSamplesPerClass do
      for c = 1, nClasses do
         local x = centers[c][1] + torch.normal(0, std)
         local y = centers[c][2] + torch.normal(0, std)
         index = index + 1
         inputs[index][1] = x
         inputs[index][2] = y
         targets[index] = c
         importances[index] = ifelse(c == 1, 1, 0.05)
      end
   end
end

makeSamples(nSamplesPerClass)

print('training data')
for t = 1, nClasses do
   for i = 1, nInputs do
      if targets[i] == t then
         print(string.format('%3d: %0.4f %0.4f %d %f',
                             i, 
                             inputs[i][1], inputs[i][2], 
                             targets[i],
                             importances[i]))
      end
   end
end


local gradient, loss, predict, nParameters =
   makeLogreg(nClasses, nDimensions)
vp(1, 'gradient', gradient)
vp(1, 'loss', loss)
vp(1, 'predict', predict)
vp(1, 'nParameters', nParameters)

local gFromDebugging = nil
if debugging  then
   -- check gradient estimates for each sample
   local theta = torch.Tensor(nParameters):zero()
   local sumG = torch.Tensor(nParameters):zero()
   for i = 1, nInputs do
      vp(2, 'targets', targets)
      vp(2, 'targets[' .. i .. ']', targets[i])
      local gEst = 
         gradientEstimate(theta, inputs[i], targets[i], importances[i])
      vp(2, 'gEst[' .. i .. ']', gEst)
      sumG = sumG + gEst
   end
   vp(2, 'sumG', sumG)

   local g = gradient(theta, inputs, targets, importances)
   gFromDebugging = g
   vp(2, 'g', g)
   assertEq(sumG, g, .0001)

   -- determine if overall gradient equals finite differences version
   local function f(theta)
      return loss(theta, inputs, targets, importances)
   end

   local epsilon = 1e-10
   local d, dh = checkGradient(f, theta, epsilon, g)
   vp(2, 'd', d)
   vp(2, 'dh', dh)
   assertEq(dh, g, .0001)
end

-- check gradient
local function check(n)
   local vp = makeVp(0, 'check')
   vp(1, 'n', n)
   vp(3, 'inputs', inputs)
   vp(3, 'targets', targets)
   vp(3, 'importances', importances)
   vp(3, 'loss', loss)
   local function f(theta)
      local vp = makeVp(0, 'check f')
      vp(1, 'theta', theta)
      vp(1, 'loss function', loss)
      local lossValue = loss(theta, inputs, targets, 'weights', importances)
      vp(1, 'loss', lossValue)
      return lossValue
   end

   -- check n random theta values
   for i = 1, n do
      local theta = torch.rand(nParameters)
      local g = gradient(theta, inputs, targets, 'weights', importances)
      vp(2, 'g', g)

      -- if epsilon == 1e-15, the finite difference version doesn't equal
      -- the directly-computed version
      local d, dh = checkGradient(f, theta, 1e-10, g)
      vp(2, 'theta', theta)
      vp(2, 'd', d)
      vp(2, 'dh', dh)
      assertEq(g, dh, .1)
   end
end

check(10)

-- run gradient descent for a specified learning rate alpha starting at 
-- theta = 0
-- ARGS:
-- alpha : number, the learning rate
-- nIterations : number, max number of iterations if > 0
-- onIncrease  : string in {'error', 'decrease'}
--               what to do if loss increases
-- RETURN
-- finalLoss  : number, loss after nIterations using alpha
-- finalTheta : 1D Tensor, final parameters
-- finalAlpha : number, may differ from original alpha
-- iterations : number, iterations completed
local function runAlpha(alpha, nIterations, onIncrease)
   print(' ')
   print('running with alpha ' .. alpha)
   local theta = torch.Tensor(nParameters):zero()
   
   local function gradientF(theta)
      return gradient(theta, inputs, targets, 'weights', importances)
   end

   local function lossF(theta)
      return loss(theta, inputs, targets, 'weights', importances)
   end

   -- declare converges if the norm2 of the gradient is small enough
   -- or if we have done nIterations > 0 stpes
   -- better alternative: if the norm2 of the gradient is small enough
   local smallEnough = .1
   local iterations = 0
   local function convergedF(newLoss, newTheta, newGradient)
      local vp = makeVp(0, 'convergedF')
      vp(1, 'newGradient', newGradient)
      iterations = iterations + 1
      local newNorm = torch.norm(newGradient)
      vp(1, 'iteration ' .. iterations .. 
            ' loss ' .. newLoss .. 
            ' norm(gradient) ' .. newNorm)
      if nIterations > 0 and iterations >= nIterations then
         return true
      else
         return newNorm < smallEnough
      end
   end

   -- optim.gd attempts to iterate until convergence
   local finalLoss, finalTheta, finalAlpha = 
      optim.gd(alpha, theta, convergedF, gradientF, lossF, onIncrease)
   vp(1, 'finalLoss ' .. finalLoss)
   vp(1, 'finalTheta', finalTheta)
   vp(1, 'finalAlpha', finalAlpha)
   return finalLoss, finalTheta, finalAlpha, iterations
end

-- search for a suitable alpha, the highest one that always has decreases
-- define possible alphas logarithmically
local alphas = 
   {.00001, .00003, .0001, .0003, .001, .003, .01, .03, .1, .3, 1, 3, 10}
--local alphas = {0.00001, 100}
local finalLosses = {}
local lowestLoss = math.huge 
local bestAlpha = nil
local nTestIterations = 50  -- recommended by Andrew Ng
local inIncrease = 'error'
for _, alpha in ipairs(alphas) do
   local lossAlwaysDecreased, finalLoss, finalTheta, finalAlpha = 
      pcall(runAlpha, alpha, nTestIterations, onIncrease)
   --runAlpha(alpha, nTestIterations, onIncrease)  -- for debugging above call
   if not lossAlwaysDecreased then
      print('error from runAlpha: ' .. finalLoss)
      assert(string.match(finalLoss, 'loss increased'), finalLoss)
      break
   end
   assert(finalAlpha == alpha, 
          'alpha ' .. alpha .. ' finalAlpha ' .. finalAlpha)
   table.insert(finalLosses, finalLoss)
   if finalLoss < lowestLoss then
      lowestLoss = finalLoss
      bestAlpha = alpha
   end
end

print('alpha/final loss after ' .. nTestIterations .. ' test iterations')
for i, alpha in ipairs(alphas) do
   if finalLosses[i] == nil then
      vp(1, string.format('%6g too large', alpha))
   else
      vp(1, string.format('%6g %g', alpha, finalLosses[i]))
   end
end
vp(1, 'best alpha is ' .. bestAlpha)


-- training using the best alpha found
vp(1, 'final training iterations')

local fittedAlpha = bestAlpha
local trainedLoss, trainedTheta, trainedAlpha, trainedIterations = 
   runAlpha(fittedAlpha, 0, 'error')

vp(1, 'trainedLoss', trainedLoss)
vp(1, 'trainedTheta', trainedTheta)
vp(1, 'trainedAlpha', trainedAlpha)
vp(1, 'trainedIterations', trainedIterations)

-- used fitted model to check accuracy on training data
local function fitted(theta)
   local vp = makeVp(0, 'fitted')
   local mles, probs = predict(theta, inputs)
   return mles
end


local predictions = fitted(trainedTheta)
local nCorrect = 0
for i = 1, nInputs do
   print(string.format('%3d %8.6f %8.6f %d %d',
                       i, 
                       inputs[i][1], inputs[i][2], 
                       targets[i], 
                       predictions[i]))
   if predictions[i] == targets[i] then
      nCorrect = nCorrect + 1
   end
end
print('fraction correct ' .. nCorrect / nInputs)

local function solution(theta)
   local vp = makeVp(0, 'solution')
   for xValue = 0, 1, 0.2 do
      for yValue = 0, 1, .2 do
         local input = torch.Tensor{{xValue, yValue}} -- one row
         local mles = predict(theta, input)
         print(string.format('x %3.1f y %3.1f fitted value %d',
                             xValue, yValue, mles[1]))
      end
   end
end

print(' ')
print('Solution at various grid points')
solution(trainedTheta)

print('end of regression test 1 makeLogRegImportance')
