-- makeLogRegImportance_rtest2.lua
-- 1 dimensions, 3 classes, varying importance

-- TODO: test on weighted training points

require 'checkGradient'
require 'ifelse'
require 'makeLogreg'
require 'optim'
require 'optim_vsgdfd'      -- self-tuning SGD via Tom Schaul
require 'makeVp'

local verbose = 2
local vp = makeVp(verbose)

local function assertEq(a, b, tol)
   assert(math.abs(a - b) < tol)
end

torch.manualSeed(123)

local nClasses = 3
local nDimensions = 1
local nInputsPerClass = 50
-- equal importances
local function generateData1(nInputsPerClass)
   nInputs = nInputsPerClass * nClasses  -- GLOBAL
   local inputs = torch.Tensor(nInputs, nDimensions)
   local targets = torch.Tensor(nInputs)
   local importances = torch.Tensor(nInputs)
   local index = 0
   for i = 1, nInputsPerClass do
      for c = 1, nClasses do
         local x = torch.uniform(0, 1) + c
         index = index + 1
         inputs[index][1] = x
         targets[index] = c
         importances[index] = 1
      end
   end
   return inputs, targets, importances
end


inputs, targets, importances = generateData1(nInputsPerClass)

local function printData()
   print('training data')
   local nInputs = inputs:size(1)
   for c = 1, nClasses do
      for i = 1, nInputs do
         if targets[i] == c then
            print(string.format('%3d: %8.6f %d',
                                i, inputs[i][1], targets[i]))
         end
      end
   end
end         

printData()

-- return index of largest value in vector
local function maxIndex(v)
   local largestValue = - math.huge
   local largestIndex = nil
   for i = 1, v:size(1) do
      local value = v[i]
      if value > largestValue then
         largestValue = value
         largestIndex = i
      end
   end
   return largestIndex
end

-- gradient descent
-- RETURN
-- lossValue : number, loss at final theta
-- finalTheta : 1D Tensor, parameters after final iteration
local function gd(alpha, nIterations, theta,
                  loss, gradient, decrease)
   local vp = makeVp(2, 'gd')
   local reset = ifelse(decrease == nil, false, decrease)
   vp(1, 'alpha', alpha)
   vp(1, 'initial theta', theta)
   vp(1, 'reset', reset)
   local thetaCopy = theta:clone()
   local prevLoss = nil
   local alphaResets = 0
   for iteration = 1, nIterations do
      local d = gradient(thetaCopy, inputs, targets, importances)
      --vp(2, 'thetaCopy before update', thetaCopy)
      local updatedTheta = thetaCopy - d * alpha
      lossValue = loss(thetaCopy)
      vp(1, string.format('%d loss %g theta %.4g %.4f d %.4g %.4g',
                          iteration, lossValue, 
                          thetaCopy[1], thetaCopy[2],
                          d[1], d[2]))
      if prevLoss and prevLoss < lossValue then
         vp(2, 'd', d)
         vp(2, 'thetaCopy', thetaCopy)
         vp(2, 'updatedTheta', updatedTheta)
         vp(2, 'lossValue', lossValue)
         vp(2, 'alphaResets', alphaResets)
         if not reset then
            error('loss not decreasing and no reset for alpha ' .. alpha)
         end
         alphaResets = alphaResets + 1
         if alphaResets >= 3 then
            error('loss not decreasing for alpha ' .. alpha)
         end
         alpha = .7 * alpha
         print('new alpha ' .. alpha)
         -- don't update thetaCopy or prevLoss
      else
         alphaResets = 0
         thetaCopy = updatedTheta
         prevLoss = lossValue
      end

   end
   return lossValue, thetaCopy
   
end

local gradient, loss, predict, nParameters =
   makeLogreg(nClasses, nDimensions)

local function lossF(theta)
   local totalLoss =  loss(theta, inputs, targets, 'weights', importances)
   return totalLoss
end

local function gradientF(theta)
   return gradient(theta, inputs, targets, 'weights', importances)
end

-- check gradient
local function check(n)
   local vp = makeVp(0, 'check')
   for i = 1, n do
      local theta = torch.rand(nParameters)
      local g = gradientF(theta)
      local d, dh = checkGradient(lossF, theta, 1e-3, g)
      vp(1, 'theta', theta)
      vp(1, 'd', d)
      vp(1, 'g', g)
      vp(1, 'dh', dh)
      for j = 1, nParameters do
         assertEq(g[j], dh[j], .0001)
      end
   end
end

check(100)

-- test alpha
-- RETURN
-- loss       : number, loss after nIterations using alpha
-- finalTheta : 1D Tensor, final parameters
local function runAlpha(alpha, nIterations, decrease)
   print(' ')
   print('running with alpha ' .. alpha)
   local theta = torch.Tensor(nParameters):zero()
   theta:fill(1)
   local loss, finalTheta = 
      gd(alpha, nIterations, theta, lossF, gradientF, decrease)
   print('final loss ' .. loss)
   vp(1, 'finalTheta', finalTheta)
   return loss, finalTheta
end

local alphas = 
   {.00001, .00003, .0001, .0003, .001, .003, .01, .03, .1, .3, 1, 3, 10}
--local alphas = {0.00001, 100}
local finalLoss = {}
local lowestLoss = math.huge 
local bestAlpha = nil
for _, alpha in ipairs(alphas) do
   local ok, loss, theta = pcall(runAlpha,alpha, 10)
   if not ok then
      print('error from runAlpha: ' .. loss)
      break
   end
   table.insert(finalLoss, loss)
   if loss < lowestLoss then
      lowestLoss = loss
      bestAlpha = alpha
   end
end

print('alpha/final loss')
for i, alpha in ipairs(alphas) do
   if finalLoss[i] == nil then
      break
   end
   print(string.format('%16g %16g', alpha, finalLoss[i]))
end
print('best alpha is ' .. bestAlpha)
print('final training iterations')

local fittedAlpha = bestAlpha
local trainedLoss, trainedTheta = runAlpha(fittedAlpha, 1000, true)

local function fitted(theta)
   local vp = makeVp(0, 'fitted')
   local predictions = predict(theta, inputs)
   return predictions
end

local function solution(theta)
   local vp = makeVp(0, 'solution')
   for xValue = 1, 4, 0.1 do
      local x = torch.Tensor{{x}}  -- 2D Tensor
      local predictions = predict(theta, x)
      print(string.format('x %3.1f fitted value %d',
                          xValue, prediction[1]))
   end
end

local predictions = fitted(trainedTheta)
local nCorrect = 0
for i = 1, nInputs do
   print(string.format('%3d %8.6f %d %d',
                       i, inputs[i][1], targets[i], predictions[i]))
   if predictions[i] == targets[i] then
      nCorrect = nCorrect + 1
   end
end
print('fraction correct ' .. nCorrect / nInputs)

solution(trainedTheta)

print('end of regression test 3 makeLogreg')