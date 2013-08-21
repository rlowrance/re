-- optim_vsgdfd_rtest1.lua
-- regression test

-- ref: http://torch.cogbits.com/doc/tutorials_supervised/

require 'isnan'
require 'makeVp'
require 'optim'
require 'optim_vsgdfd'

local verbose = 0
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

torch.manualSeed(1234)

function makeGradientsFunction(batchsize, verbose)
   local index = 0
   local lastBatchId = 0
   local lastBatchIndices = {}  -- the indices in the current batch
   local function gradients(w, batchId)
      local verbose = verbose or 0
      --verbose = 2
      local vp = makeVp(verbose)
      vp(1, 'gradients w', w)
      vp(1, 'gradients batchId', batchId)
      
      local function gradient(index, w)
         -- return loss, gradient wrt w at sample[index]
         -- loss = (w'x - y)^2 = (prediction - y)^2 = error^2
         -- gradient = dLoss_dW = 2(prediction - y)x = 2*error*x
         vp(1, 'gradient index', index)
         vp(1, 'gradient w', w)
         vp(1, 'gradient batchsize', batchsize)
         
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
      end -- function gradient
      
      
      -- determine all sample indices in the batch
      if lastBatchId ~= batchId then
         -- reformulate indices in the new batch
         lastBatchIndices = {}
         for i = 1, batchsize do
            index = index + 1
            if index > p then
               index = 1
            end
            lastBatchIndices[#lastBatchIndices + 1] = index
         end
      end

      -- determine all gradients
      local g = {}
      local firstLoss = nil
      for _, index in ipairs(lastBatchIndices) do
         local loss, nextGradient = gradient(index, w)
         if firstLoss == nil then
            firstLoss = loss
         end
         g[#g + 1] = nextGradient
      end
      
      vp(1, 'gradients loss', firstLoss)
      vp(1, 'gradients g', g)
      return firstLoss, g
   end -- gradients

   return gradients
end -- makeGradientsFunction

-- unit test gradients
local gradients = makeGradientsFunction(1) -- batchsize == 1
local w = torch.Tensor{1,2,3}
local loss, gs = gradients(w, 1)
vp(2, 'loss', loss)
vp(2, 'gs', gs)
assert(loss == 225)
local gs1 = gs[1]
assert(gs1[1] == -30)
assert(gs1[2] == -180)
assert(gs1[3] == -120)

-- run a test
function trainModel(nEpochs, batchsize, verbose)
   local verbose = verbose or 0;
   local vp = makeVp(verbose)
   vp(1, 'trainModel nEpochs', nEpochs)
   vp(1, 'trainModel batchsize', batchsize)
   local w = torch.rand(3) -- initialize weights randomly
   vp(2, 'trainModel w', w)
   local state = {verbose=0}  -- essentially no parameters
   local gradients = makeGradientsFunction(batchsize)
   local avgLoss
   for epoch = 1, nEpochs do
      local cumLoss = 0
      -- cycle over data
      for i = 1, p do
         --if epoch == 2986 then verbose = 2; state.verbose = 2 end
         local newW, fs = optim.vsgdfd(gradients, w, state)
         vp(2, 'trainModel newW', newW)
         vp(2, 'trainModel fs', fs)
         vp(2, 'trainModel state', state)
         w = newW
         local loss = fs[1]
         assert(not isnan(loss))
         cumLoss = cumLoss + loss
         --if i == 2 then stop() end
      end
      avgLoss = cumLoss / p
      vp(1, 'trainModel epoch ' .. epoch .. ' avgLoss ' .. cumLoss / p)
      --vp(2, 'trainModel ending weights', w)
   end
   -- test model accuracy
   vp(1, 'trainModel final w', w)
   vp(1, 'trainModel final avgLoss', avgLoss)
   return avgLoss, w
end -- trainModel

local function testAccuracy(w, verbose)
   local verbose = verbose or 0
   local function predict(w, fertilizer, insecticide)
      local result = w[1] + w[2] * fertilizer + w[3] * insecticide
      return result
   end
   
   local cumSquaredError = 0
   vp(1, 'Accuracy on training data')
   for i = 1, p do
      local actual = data[i][1]
      local prediction = predict(w, data[i][2], data[i][3])
      local error = actual - prediction
      vp(1, string.format('i %2d actual %f prediction %f abs(error) %f',
                          i, actual, prediction, math.abs(error)))
      local se = error * error
      cumSquaredError = cumSquaredError + se
   end
   local mse = cumSquaredError / p
   local rmse = math.sqrt(mse)
   return rmse
end

function runTest(nEpochs, batchsize, verbose)
   local vp = makeVp(verbose)
   local avgLoss, w = trainModel(nEpochs, batchsize, verbose)
   local rmse = testAccuracy(w, verbose)
   vp(0, string.format('nEpochs %d batchsize %2d avgLoss %6.2f ' ..
                       'w [%6.2f,%6.2f,%6.2f] rmse %f',
                       nEpochs, batchsize, avgLoss, w[1], w[2], w[3], rmse))
   return rmse
end -- runTest

local nEpochs = 1e3
local maxBatchSize = 10
local rmse = {}
for batchsize = 1, maxBatchSize do
   rmse[#rmse +  1] = runTest(nEpochs, batchsize, verbose)
end

vp(1, 'nEpochs', nEpochs)
vp(1, 'rmse by batchsize', rmse)
-- Its not true that one batch size is always better, so just accept
-- no failing as success
print('ok optim_vsgdfd_rtest1')
   