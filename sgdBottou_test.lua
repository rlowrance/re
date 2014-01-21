-- sgdBottou_test.lua
-- unit test of sgdBottou

require 'assertEq'
require 'makeVp'
--require 'optim'
require 'pressEnter'
require 'sgdBottou'
require 'sgdBottouDriver'
require 'validateAttributes'

-- The test consists of recovering the parameters w of the function
-- f(w,x) = w_1 x_1^2 + w_2 x_2^2, where w = [.5 2.5]^T using 
-- 100 sampled x values drawn randomly s.t. x_i in (0,1).
-- This test is inspired by Heath, Scientific Computing, Second Edition, p 276

local vp = makeVp(0, 'tester')

torch.manualSeed(123)

-- predict y = f(w, x), the hypothesis function (often denoted h() elsewhere)
local nDim = 2
local fCallCount = 0
local function f(w, x)
   local vp = makeVp(0, 'f')
   fCallCount = fCallCount + 1
   vp(2, 'w', w, 'x', x)
   vp(1, 'fCallCount', fCallCount)
   validateAttributes(w, 'Tensor', '1d', 'size', {2})
   validateAttributes(x, 'Tensor', '1d', 'size', {2})
   local x1 = x[1]
   local x2 = x[2]
   vp(2, 'x1', x1, 'x2', x2)
   local result = w[1] * x1 * x1 + w[2] * x2 * x2
   vp(1, 'result', result)
   return result
end

local function fTest()
   assert(0 == f(torch.Tensor{0, 0}, torch.Tensor{0, 0}))
   assert(2 == f(torch.Tensor{1, 1}, torch.Tensor{1, 1}))
   assert(41 == f(torch.Tensor{1, 2}, torch.Tensor{3, 4}))
end
fTest()
   

-- The loss is the squared loss
-- loss(w, x, y) = (y - f(w,x))^2 = error^2
-- The gradient of the loss at sample (x,y) has these components at w_i
-- gradient_i = 2 (y - f(w,x)) (- 2 * x_i) = 2 * error * (-2 x_i)
-- gradient_i = 2 * error * - x_i^2
local function lossGradient(w, x, y)
   local vp = makeVp(0, 'lossGradient')
   vp(1, 'w', w, 'x', x, 'y', y)
   validateAttributes(w, 'Tensor', '1d')
   validateAttributes(x, 'Tensor', '1d')
   validateAttributes(y, 'number')
   local error = y - f(w,x)
   vp(2, 'f(w,x)', f(w,x), 'error', error)
   local gradient = torch.Tensor(nDim)
   for d = 1, nDim do
      gradient[d] = 2 * error * (- x[d] * x[d])
   end
   local loss = error * error
   vp(1, 'loss', loss, 'gradient', gradient)
   return loss, gradient
end

local function lossGradientTest()
   local vp = makeVp(0, 'lossGradientTest')
   local loss, gradient = 
      lossGradient(torch.Tensor{0,0}, torch.Tensor{0,0}, 0)
   assert(loss == 0)
   assertEq(gradient, torch.Tensor{0,0}, 0)
   
   local loss, gradient =
      lossGradient(torch.Tensor{1,2}, torch.Tensor{3,4}, 5)
   vp(2, 'gradient', gradient)
   -- prediction = 41, 
   local error = 41 - 5
   assert(loss == error * error)
   assertEq(gradient, 
            torch.Tensor{2 * error * (3 * 3), 2 * error * (4 * 4)},
            0)
end
lossGradientTest()

-- Generate the training samples into X and Y
local nSamples = 1000
local X = torch.rand(nSamples, 2)
local Y = torch.Tensor(nSamples)
local trueW = torch.Tensor{.5, 2.5}  -- from Heath
for i = 1, nSamples do
   Y[i] = f(trueW, X[i]) + torch.normal(0, .1)  -- add Gaussian noise
   --Y[i] = f(trueW, X[i])                        -- no noise
end

-- Opfunc
local opfuncNextIndex = 0
local function opfunc(w, index)
   local vp = makeVp(0, 'opfunc')
   vp(1, 'w', w, 'index', index)
   validateAttributes(w, 'Tensor', '1d', 'size', {2})
   if index == nil then
      opfuncNextIndex = opfuncNextIndex + 1
      if opfuncNextIndex > nSamples then
         opfuncNextIndex = 1
      end
      index = opfuncNextIndex
   end
   local lossValue, gradientValue = lossGradient(w, X[index], Y[index])
   vp(1, 'lossValue', lossValue, 'gradientValue', gradientValue)
   validateAttributes(gradientValue, 'Tensor')
   return lossValue, gradientValue
end

-- check the gradient 
local function checkGradient(w)
   local vp = makeVp(0, 'checkGradient')
   vp(1, 'w', w)

   -- check the gradient at one example
   local function checkGradient1(w, index)
      local _, gradient = opfunc(w, index)
      -- compute finite difference gradient
      local epsilon = 1e-4
      local fdGradient = torch.Tensor(nDim)
      for d = 1, nDim do
         local delta = torch.Tensor(nDim):zero()
         delta[d] = epsilon

         local wPlus = w + delta
         local lossPlus = opfunc(wPlus, index)

         local wMinus = w - delta
         local lossMinus = opfunc(wMinus, index)

         fdGradient[d] = (lossPlus - lossMinus) / (2 * epsilon)
         vp(3, 'delta', delta)
         vp(3, 'wPlus', wPlus, 'wMinus', wMinus)
         vp(3, 'lossPlus', lossPlus, 'lossMinus', lossMinus)
         vp(3, 'lossPlus - lossMinus', lossPlus - lossMinus)
         vp(2, string.format('index %d gradient[%d]=%f fdGradient[%d]=%f',
                             index, d, gradient[d], d, fdGradient[d]))
      end
      local totalAbsError = 0
      for d = 1, nDim do
         totalAbsError = totalAbsError + math.abs(gradient[d] - fdGradient[d])
      end
      local avgError = totalAbsError / nDim
      vp(2, 'avgError', avgError)  -- this condition does not have to hold!
      assert(avgError < epsilon)
   end

   -- check the gradient at w and the first few samples
   for index = 1, 10 do
      vp(2, 'index', index)
      checkGradient1(w, index)
   end
end
checkGradient(torch.rand(nDim))

-- Which etas to evaluate; the "candidate etas"
-- the currentEta is always included in the candidate etas
local function newEtas(currentEta)
   local vp = makeVp(0, 'newEtas')
   vp(1, 'currentEta', currentEta)
   local candidates = {.7 * currentEta, 1.3 * currentEta}
   vp(1, 'candidates', candidates)
   return candidates
end

-- configure the driver
global = {}
global.reportTiming = {}
global.reportTiming.sgdBottouDriver = false

local config =                    -- passed to optim.sgdBottou
   {nSamples = nSamples,          -- number of training samples available
   nSubsamples = .1 * nSamples,   -- number of samples to use when evaluating candidate
   eta = 1,                       -- initial eta
   newEtas = newEtas,             -- generate candidate etas from given eta
   evalCounter = .5 * nSamples,   -- generate new eta every evalCounter evaluations
   printEta=false}                -- print eta when it changes
local initialX = torch.rand(2)    -- start at random point
local tolX = 1e-3
local tolF = 1e-3
local maxEpochs = 100
local verbose = 0                 -- print avg loss and weights at end of each epoch

local xStar, avgLoss, state = 
   sgdBottouDriver(opfunc, config, nSamples, initialX, 
                   tolX, tolF, maxEpochs,
                   verbose)

vp(1, 'etas used', state.etas)   
vp(1, 'number of times f was called', fCallCount)
vp(1, 'optim weights found', xStar)

local cumLoss = 0
for i = 1, nSamples do
   cumLoss = cumLoss + lossGradient(xStar, X[i], Y[i])
end
local avgLoss = cumLoss / nSamples
vp(1, 'average loss on training samples at optimal weights', avgLoss)
assert(avgLoss < 0.1)

print('ok optim.sgdBottou')
