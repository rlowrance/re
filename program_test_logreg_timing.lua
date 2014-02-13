-- program_test_logreg_timing.lua
-- Determine how long multinomial logistic regression should run
-- Use problem size typically of HEATING.CODE imputation:
--   k = 70
--   nClasses = 14

require 'makeVp'
require 'nn'
require 'optim'
require 'Random'
require 'time'

local function makeModel(nFeatures, nClasses)
   local model = nn.Sequential()
   model:add(nn.Linear(nFeatures, nClasses))
   model:add(nn.LogSoftMax())
   return model
end

local function makeCriterion()
   return nn.ClassNLLCriterion()
end

local function makeLossGradient(model, criterion, input, target)
   local vp = makeVp(1, 'makeLossGradient')
   vp(1, 'model', model, 'criterion', criterion, 'input', input, 'target', target)
   local function lossGradient(theta)
      local vp = makeVp(0, 'lossGradient')
      vp(1, 'theta', theta)

      local parameters, gradientParameters = model:getParameters()

      if parameters ~= theta then
         parameters:copy(theta)
      end

      gradientParameters:zero()

      local output = model:forward(input)
      local loss = criterion:forward(output, target)
      local df_do = criterion:backward(output, target)
      model:backward(input, df_do)  -- set gradientParameters

      -- normalize for input size
      local nInput = input:size(1)

      return loss / nInput, gradientParameters:div(nInput)
   end

   return lossGradient
end

-- return new theta and loss at other theta
local function step(lossGradient, theta, eta)
   local config = {learningRate = eta}
   local newTheta, loss = optim.sgd(lossGradient, theta, config)
   return newTheta, loss
end

local function makeData(nClasses, nFeatures, nSamples)
   local X = torch.rand(nSamples, nFeatures)
   local y = Random:integer(nSamples, 1, nClasses)
   return {X = X, y = y}
end

-- MAIN PROGRAM

local vp = makeVp(2, 'main program')

-- configure
local nSamples = 70
local nFeatures = 8
local nClasses = 14

local data = makeData(nClasses, nFeatures, nSamples)
local initialTheta = torch.rand((nFeatures + 1) * nClasses)
print('initialTheta:size()', initialTheta:size())

local model = makeModel(nFeatures, nClasses)
local criterion = makeCriterion()
local lossGradient = makeLossGradient(model, criterion, data.X, data.y)
local eta = .1 

local nIterations = 10000
local totalCpu = 0
local totalWallclock = 0
local finalTheta = nil
for iteration = 1, nIterations do
   local cpu, wallclock, nextTheta, loss = time('both', step, lossGradient, initialTheta, eta)
   finalTheta = nextTheta
   totalCpu = totalCpu + cpu
   totalWallclock = totalWallclock + wallclock
end

vp(1, 'finalTheta', finalTheta)
print(string.format('average seconds cpu %f wallclock %f', totalCpu / nIterations, totalWallclock / nIterations))
