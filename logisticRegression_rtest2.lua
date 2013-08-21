-- logisticRegression_rtest2.lua
-- test on example in tutorial at 
-- http://torch.cogbits.com/doc/tutorials_supervised/

require 'Dataframe'
require 'logisticRegression'
require 'makeVp'
require 'optim'
require 'sweep2'
require 'nn'

local verbose = 0
local vp = makeVp(verbose)

manualSeed = 123
torch.manualSeed(manualSeed)

-- read data
local numberColumns = {'num', 'brand', 'female', 'age'}
local df = Dataframe.newFromFile2{file='logisticRegression_rtest2.csv',
                                  numberColumns=numberColumns
                                  }

local inputs = df:asTensor{'age', 'female'}
local targets = df:asTensor{'brand'}

local function minColumn(tensor, col)
   vp(1, 'tensor', tensor)
   local result = math.huge
   for i = 1, tensor:size(1) do
      local entry = tensor[i][col]
      if entry < result then result = entry end
   end
   return result
end

local function maxColumn(tensor, col)
   local result = -math.huge
   for i = 1, tensor:size(1) do
      local entry = tensor[i][col]
      if entry > result then result = entry end
   end
   return result
end

local minAge = minColumn(inputs, 1)
local maxAge = maxColumn(inputs, 1)
local minFemale = minColumn(inputs, 2)
local maxFemale = maxColumn(inputs, 2)
local minBrand = targets:min()
local maxBrand = targets:max()
print(string.format('range age is from %d to %d', minAge, maxAge))
print(string.format('range female is from %d to %d', minFemale, maxFemale))
print(string.format('range brand is from %d to %d', minBrand, maxBrand))

vp(2, 'targets', targets)

-- copy example code from
-- https://github.com/clementfarabet/torch7-demos/blob/master/logistic-regression/example-logistic-regression.lua

model = nn.Sequential()
model:add(nn.Linear(2, 3))
model:add(nn.LogSoftMax())

criterion = nn.ClassNLLCriterion()

x, dl_dx = model:getParameters()

feval = function(xNew)
  vp(1, 'feval xNew', xNew)
  if x ~= xNew then x:copy(xNew) end

  _nidx_ = (_nidx_ or 0) + 1
  if _nidx_ > inputs:size(1) then _nidx_ = 1 end

  local input = inputs[_nidx_]
  local t = targets[_nidx_]
  vp(2, 'index of training sample', _nidx_)
  vp(2, 'input', input)
  vp(2, 't', t)

  dl_dx:zero()
  
  local modelOutput = model:forward(input)
  vp(2, 'modelOutput (prediction)', modelOutput)
  local lossX = criterion:forward(model:forward(input), t)
  model:backward(input, criterion:backward(model.output, t))
  if false then
    local weights, gradWeights = model:getParameters()
    vp(1, 'feval weights', weights); vp(1, 'gradWeights', gradWeights)
    vp(1, 'lossX', lossX); vp(1, 'dl_dx', dl_dx)
  end

  return lossX, dl_dx
end

sgdParams = {learningRate = 1e-3,
             learningRateDecay = 1e-4,
             weightDecay = 0,
             momentum = 0}

print('training as per text')

local nEpochs = 1
for epoch = 1, nEpochs do
  cumulativeLoss = 0
  for i = 1, inputs:size(1) do
    vp(1,'x before update', x)
    vp(1, 'sgdParams', sgdParams)
    _, fs = optim.sgd(feval, x, sgdParams)
    cumulativeLoss = cumulativeLoss + fs[1]
    vp(1, 'fs', fs)
    vp(1, 'cumulativeLoss', cumulativeLoss) 
    --if i == 2 then stop() end
  end
  vp(1, '# samples', inputs:size(1))
  avgLoss = cumulativeLoss / inputs:size(1)
  vp(1, 'epoch ' .. epoch .. ' of ' .. nEpochs .. ' avgLoss ' .. avgLoss)
  --stop()
end
--stop()

-- assess accuracy
function maxIndex(v)
  maxValue = -math.huge
  maxI = 0
  for i = 1, v:size(1) do
    if v[i] > maxValue then
      maxI = i
      maxValue = v[i]
    end
  end
  return maxI
end

exampleNAccurate = 0
for i = 1, inputs:size(1) do
  local prediction = maxIndex(model:forward(inputs[i]))
  if prediction == targets[i] then 
    exampleNAccurate = exampleNAccurate + 1
  end
end
vp(0, 'number of epochs', nEpochs)
vp(0, 'model weights', x)
vp(0, 'exampleNAccurate', exampleNAccurate)
vp(0, 'example accuracy', exampleNAccurate / inputs:size(1))

-- determine best hyperparameters
local function fit(learningRate, learningRateDecay,
                   nEpochs, verbose)
   local vp = makeVp(0)
   nEpochs = nEpochs or 100
   verbose = verbose or 0
   vp(1, 'fit learningRate', learningRate)
   vp(1, 'fit learningRateDecay', learningRateDecay)
   vp(1, 'fit nEpochs', nEpochs)
   vp(1, 'fit verbose', verbose)
   local optimParams = {learningRate=learningRate,
                        learningRateDecay=learningRateDecay}
   local lambda = 0.001
   local state, predict = logisticRegression{inputs=inputs,
                                             targets=targets,
                                             epochs=nEpochs,
                                             lambda=lambda,
                                             optimFunction=optim.sgd,
                                             optimParams=optimParams,
                                             verbose=verbose}
   return state, predict
end

minLr = nil
minLrd = nil
if false then
   print('\nexploring hyperparameter space')
   local lrs = {1, .1, .01, .001}
   local lrds = {0, .1, .01, .001}
   --lrs = {1, .1}  -- for testing
   --lrds = {0, .1}
   print('learning rates tested', lrs)
   print('learning rate decays tested', lrds)
   result = sweep2(fit, lrs, lrds)
   minAvgLoss = math.huge
   minLr = nil
   minLrd = nil
   for _, lr in ipairs(lrs) do
      for _, lrd in ipairs(lrds) do
         --print('result[lr]'); print(result[lr])
         --print('result[lr][lrd]'); print(result[lr][lrd])
         local avgLosses = result[lr][lrd].avgLoss
         local lastAvgLoss = avgLosses[#avgLosses]
         print(string.format('lr %0.6f lrd %0.6f lastAvgLoss %f',
                             lr, lrd, lastAvgLoss))
         if lastAvgLoss < minAvgLoss then
            minAvgLoss = lastAvgLoss
            minLr = lr
            minLrd = lrd
         end
      end
   end
else
   print('\nUsing hyperparameters found on previous run')
   minLr = 1  
   minLrd = 0.1
end
print('learning rate minimizer = ' .. minLr)
print('learning rate decay minimizer = ' .. minLrd)

-- here is the actual test of the logisticRegression function

torch.manualSeed(manualSeed)
local optimParams = {learningRate = minLr,
                     learningRateDecay = minLrd,
                     weightDecay = 0,
                     momentum = 0}
local status, predict = fit(minLr, minLrd, 10000, 1) -- 1000 epochs, verbose 1
print('status'); print(status)
print('predict'); print(predict)
local predictions, probs = predict{inputs=inputs}  -- predict on training data
vp(0, 'predictions', predictions)
vp(0, 'probs', prob)
local p = inputs:size(1)
local isAccurate = 0
for i = 1, p do
   if predictions[i] == targets[i] then
      isAccurate = isAccurate + 1
   end
end
vp(0, 'weights from library code', status.weights)
vp(0, 'rtest number accurate ', isAccurate) 
vp(0, 'rtest p = ', p)
vp(0, 'test accuracy is ' , isAccurate / p)

-- compare to results from original source
local function maxIndex3(a, b, c)
  if a > b and a > c then return 1
  elseif b > a and b > c then return 2
  else return 3 end
end

local function predictText(input)
  local age = input[1]
  local female = input[2]
  local logit1 = 0
  local logit2 = -11.774655 + 0.523814 * female + 0.368206 * age
  local logit3 = -22.721396 + 0.465941 * female + 0.685908 * age
  local uprob1 = math.exp(logit1)
  local uprob2 = math.exp(logit2)
  local uprob3 = math.exp(logit3)
  local z = uprob1 + uprob2 + uprob3
  local prob1 = (1 / z) * uprob1
  local prob2 = (1 / z) * uprob2
  local prob3 = (1 / z) * uprob3
  return maxIndex3(prob1, prob2, prob3), prob1, prob2, prob3
end -- function predictText

local function mark(prediction, actual)
   if prediction == actual then 
      return ' '
   else
      return '*'
   end
end --mark

print('Results on possible inputs')
for age = minAge, maxAge do
   for female = minFemale, maxFemale do
      local input = torch.Tensor(2)
      input[1] = age
      input[2] = female
      local textPrediction, textProb1, textProb2, textProb3 = predictText(input)
      local input2D = torch.Tensor(1, 2)
      input2D[1][1] = input[1]
      input2D[1][2] = input[2]
      local libPrediction, libProbs = predict{inputs=input2D}
      local libProb1 = libProbs[1][1]
      local libProb2 = libProbs[1][2]
      local libProb3 = libProbs[1][3]
      print(string.format('age %2d f %d ' ..
                          'text %d p1 %0.2f p2 %0.2f p3 %02.f ' ..
                          'lib %d p1 %0.2f p2 %0.2f p3 %0.2f',
                          age, female,
                          textPrediction, textProb1, textProb2, textProb3,
                          libPrediction[1], libProb1, libProb2, libProb3))
   end
end
stop()

textPrediction = predictText{inputs=input2D}
print('Result on training data')
print('* == prediction differs from actual')
print(string.format('ndx age female actual pUs  pText'))
local nWrongText = 0
local nWrongLib = 0
local nDifferent = 0
for i = 1, p do
  local input = inputs[i]
  assert(input ~= nil, 'nil input for i = ' .. i)
  local input2D = torch.Tensor(1, 2)
  input2D[1][1] = input[1]
  input2D[1][2] = input[2]
  local target = targets[i]
  local textPrediction = predictText(input)
  local libPredictions, libProbs = predict{inputs=input2D}
  local libPrediction = libPredictions[1]
  local libProbs = libProbs[1]
  vp(2, 'libPrediction', libPrediction)
  vp(2, 'libProbs', libProbs)
  if target ~= textPrediction or 
     target ~= libPrediction or 
     textPrediction ~= targetPrediction then
     print(string.format('%3d %3d %6d %6d %3d%s %5d%s ' ..
                         'p1 %0.2f p2 %0.2f p3 %0.2f',
                         i, input[1], input[2], target,
                         libPrediction, mark(libPrediction, target),
                         textPrediction, mark(textPrediction, target),
                         libProbs[1], libProbs[2], libProbs[3]))
     if target ~= textPrediction then
        nWrongText = nWrongText + 1
     end
     if target ~= libPrediction then
        nWrongLib = nWrongLib + 1
     end
     if textPrediction ~= libPrediction then
        nDifferent = nDifferent + 1
     end
  end
end
print(string.format('errors using lib = %d, errors using text = %d',
                    nWrongLib, nWrongText))
print(string.format('accuracy using lib = %f, accuracy using text = %f',
                    (p - nWrongLib) / p, (p - nWrongText) / p))
print(string.format('number times with different estimates = %d', nDifferent))
print('avg loss in final epoch = ' .. status.avgLoss[#status.avgLoss])
print('finished')
