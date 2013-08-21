-- optim_vsgdfd_rtest1.lua
-- regression test

-- ref: http://torch.cogbits.com/doc/tutorials_supervised/

require 'isnan'
require 'makeVp'
require 'optim'
require 'optim_vsgdfd'
require 'optim_makeAvgOptim'

local verbose = 2
local vp = makeVp(verbose)

torch.manualSeed(123456)

-- columns: corn, fertilizer, insecticide
data = torch.Tensor{
   {40,  6,  4},
   {44, 10,  4},
   {46, 12,  5},
   {48, 14,  7},
   {52, 16,  9},
   {58, 18, 12},
   {60, 22, 14},
   {68, 24, 20},
   {74, 26, 21},
   {80, 32, 24}
}
local p = data:size(1)

-- model:  corn ~ w1 + w2 * fertilizer + w3 * insecticide
-- fitted: corn ~ 31.98 + 0.65 fertilizer + 1.11 insecticide
-- return loss, {gradients(w)} for the batch which has size 1
torch.manualSeed(1234)
local batchsize = 2
local index = 0
local lastBatchId = 0
local function gradients(w, batchId)
   local vp = makeVp(0)
   vp(1, 'gradients w', w)
   vp(1, 'gradients batchId', batchId)

   local function gradient(index, w)
      -- return loss, gradient wrt w at sample[index]
      -- loss = (w'x - y)^2 = (prediction - y)^2 = error^2
      -- gradient = dLoss_dW = 2(prediction - y)x = 2*error*x
      vp(1, 'gradient index', index)
      vp(1, 'gradient w', w)
      
      local corn = data[index][1]
      local fertilizer = data[index][2]
      local insecticide = data[index][3]
      vp(2,'corn ' .. corn .. 
           ' fertilizer ' .. fertilizer .. 
           ' insecticide ' .. insecticide)
      
      local prediction = w[1] + w[2] * fertilizer + w[3] * insecticide
      local error = prediction - corn
      local loss = error * error
      vp(2, 'prediction', prediction)
      vp(2, 'error', error)
      vp(2, 'loss', loss)
      
      local result = torch.Tensor{1, fertilizer, insecticide} * 2 * error
      vp(1, 'gradient loss', loss)
      vp(1, 'gradient result', result)
      
      return loss, result
   end

   local function incrementIndex()
      index = index + 1
      if index > p then
         index = 1
      end
   end

   if lastBatchId ~= batchId then
      -- use next sample if batch id has changed
      incrementIndex()
   end
   
   local loss, g = gradient(index, w)
   g = {g}
   if batchsize > 1 then
      for b = 2, batchsize do
         incrementIndex()
         local _, nextG = gradient(index, w)
         g[#g + 1] = nextG
      end
   end
   vp(1, 'gradients loss', loss)
   vp(1, 'gradients g', g)
   return loss, g
end

-- unit test gradients
index = 0
local w = torch.Tensor{1,2,3}
local loss, gs = gradients(w, 1)
vp(2, 'loss', loss)
vp(2, 'gs', gs)
assert(loss == 225)
local gs1 = gs[1]
assert(gs1[1] == -30)
assert(gs1[2] == -180)
assert(gs1[3] == -120)
index = 0  -- Reset for non-testing

local nEpochs = 10000
local w = torch.rand(3) -- initialize weights randomly
vp(2, 'w', w)
local state = {verbose=0}  -- essentially no parameters
for epoch = 1, nEpochs do
   local cumLoss = 0
   -- cycle over data
   for i = 1, p do
      --if epoch == 2986 then verbose = 2; state.verbose = 2 end
      local newW, fs = optim.vsgdfd(gradients, w, state)
      vp(2, 'newW', newW)
      vp(2, 'fs', fs)
      vp(2, 'state', state)
      w = newW
      local loss = fs[1]
      assert(not isnan(loss))
      cumLoss = cumLoss + loss
   end
   vp(1, 'epoch ' .. epoch .. ' avgLoss ' .. cumLoss / p)
   --vp(2, 'ending weights', w)
end
-- test model accuracy
vp(1, 'final w', w)

local function testAccuracy(w)
   local function predict(w, fertilizer, insecticide)
      local result = w[1] + w[2] * fertilizer + w[3] * insecticide
      return result
   end
   
   local cumSquaredError = 0
   for i = 1, p do
      local actual = data[i][1]
      local prediction = predict(w, data[i][2], data[i][3])
      local error = actual - prediction
      print(string.format('i %2d actual %f prediction %f abs(error) %f',
                          i, actual, prediction, math.abs(error)))
      local se = error * error
      cumSquaredError = cumSquaredError + se
   end
   local mse = cumSquaredError / p
   local rmse = math.sqrt(mse)
   print('nEpochs = ' .. nEpochs .. 
         ' RMSE = ' .. rmse ..
         ' batchsize = ' .. batchsize)
end

print('accuracy when not averaged')
testAccuracy(w)
stop()
   
-- test makeAvgOptim

-- average exponentially
local state = {verbose=0, delta=0.001}
index = 0  -- reset index for stepping through samples
local method = 'exponential'
local methodParam = 0.2
local step, avg = optim.makeAvgOptim(gradients,state, optim.vsgdfd,
                                     method, methodParam)
local w = torch.rand(3)  -- initialize weights
for epoch = 1, nEpochs do
   local cumLoss = 0
   for i = 1, p do
      local newW, fs = step(w)
      w = newW
      cumLoss = cumLoss + fs[1]
   end
   vp(1, 'avg epoch ' .. epoch .. ' avgLoss ' .. cumLoss / p)
end

print('accuracy when averaged with method ' .. 
      method .. 
      ' param ' .. methodParam)
testAccuracy(w)

-- average simply
local state = {verbose=0, delta=0.001}
index = 0  -- reset index for stepping through samples
local method = 'arithmetic'
local methodParam = p -- average over number of samples
local step, avg = optim.makeAvgOptim(gradients,state, optim.vsgdfd,
                                     method, methodParam)
local w = torch.rand(3)  -- initialize weights
for epoch = 1, nEpochs do
   local cumLoss = 0
   for i = 1, p do
      local newW, fs = step(w)
      w = newW
      cumLoss = cumLoss + fs[1]
   end
   vp(1, 'avg epoch ' .. epoch .. ' avgLoss ' .. cumLoss / p)
end

print('accuracy when averaged with method ' .. 
      method .. 
      ' param ' .. methodParam)
testAccuracy(w)
