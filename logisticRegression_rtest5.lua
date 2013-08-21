-- logisticRegression_rtest5.lua

-- example from: http://www.mc.vanderbilt.edu/gcrc/workshop_files/2004-11-12.pdf

require 'ifelse'
require 'logisticRegression'
require 'makeVp'
require 'optim'
require 'sweep1'

verboseLevel = 1
vp = makeVp(verboseLevel)

torch.manualSeed(123)

-- dataset is on page 6
-- variables are: baseline APACHE II Score, number of patients, number of deaths
-- data are not tidy
data = {{0,1,0},
        {2,1,0},
        {3,4,1},

        {4,11,0},
        {5,9,3},
        {6,14,3},
        {7,12,4},

        {8,22,5},
        {9,33,3},
        {10,19,6},
        {11,31,5},

        {12,17,5},
        {13,32,13},
        {14,25,7},
        {15,18,7},
        {16,24,8},

        {17,27,8},
        {18,19,13},
        {19,15,7},

        {20,13,6},
        {21,17,9},
        {22,14,12},

        {23,13,7},
        {24,11,8},
        {25,12,8},
        {26,6,2},

        {27,7,5},
        {28,3,1},
        {29,7,4},
        {30,5,4},

        {31,3,3},
        {32,3,3},
        {33,1,1},
        {34,1,1},
        {35,1,1},

        {36,1,1},
        {37,1,1},
        {41,1,0}}

minScore = 0
maxScore = 41

-- these variables explain the coding of the data
score = 1       -- indices of the variables
patients = 2
deaths = 3

-- coding for target variable
patientDied = 1    
patientLived = 2

-- put data into tidy format (1 observation per row) and into format
-- needed for logistic regression

nPatients = 0
for i = 1, #data do
   nPatients = nPatients + data[i][patients]
end
vp(0, 'nPatients', nPatients)

inputs = torch.Tensor(nPatients, 1)  -- only feature is the score
targets = torch.Tensor(nPatients)    -- 1 if died, 2 if did not
index = 0
for i = 1, #data do
   for p = 1, data[i][deaths] do  
      -- once for each patient that died
      index = index + 1
      inputs[index][score] = data[i][score]
      targets[index] = patientDied  -- died within 30 days
   end
   for p = data[i][deaths] + 1, data[i][patients] do 
      -- once for each patient that lived
      index = index + 1
      inputs[index][score] = data[i][score]
      targets[index] = patientLived  -- did not die within 30 days
   end
end

vp(2, 'inputs', inputs)
vp(2, 'targets', targets)

-- death rate
function observedDeathRate(s)
   -- return observed death rate for given score or nil
   for i = 1, #data do
      if data[i][score] == s then
         return data[i][deaths] / data[i][patients]
      end
   end
   return nil
end

nDeaths = 0
for i = 1, nPatients do
   nDeaths = nDeaths + ifelse(targets[i] == patientDied, 1, 0)
end

deathRate = nDeaths / nPatients
print('nDeaths = ' .. nDeaths)
print('overall death rate = ' .. deathRate)
print(' ')
assert(math.abs(deathRate - 0.3855) < 0.001)

print('fraction of deaths conditioned on score')
for s = minScore, maxScore do
   local odr = observedDeathRate(s)
   if odr then
      print(string.format('score %2d observed death rate %f',
                          s, odr))
   end
end

-- fit logistic regression model using specific hyperparameters
function test1(learningRate, nEpochs, verbose)
   nEpochs = nEpochs or 100
   verbose = verbose or 0
   local optimParams = {learningRate=learningRate,
                        learningRateDecay=0}
   local lambda = 0.001
   local state, predict = logisticRegression{inputs=inputs,
                                    targets=targets,
                                    epochs=nEpochs,
                                    lambda=lambda,
                                    optimFunction=optim.sgd,
                                    optimParams=optimParams,
                                    verbose=verbose}
   return {state, predict}
end

minimizer = nil
if false then
   print('\nExploring hyperparameter space')
   seq1 = {1, 0.1, 0.01, 0.001, 0.0001, 0.00001, 0.000001} -- minimizer is 0.001
   result = sweep1(test1, seq1)
   print('result of sweep')
   minAvgLoss = math.huge
   minimizer = nil
   for _, v1 in ipairs(seq1) do
      local avgLoss = result[v1][1].avgLoss
      local lastAvgLoss = avgLoss[#avgLoss]
      print(string.format('lr %0.6f lastAvgLoss %f',
                          v1, lastAvgLoss))
      if lastAvgLoss < minAvgLoss then
         minAvgLoss = lastAvgLoss
         minimizer = v1
      end
   end
else
   print('using pre-determined minimizer')
   minimizer = 0.001
end

print('\nFitting model at minimizer, which is ' .. minimizer)
statePredict = test1(minimizer, 1000, 0)  -- run for minimizing learning rate
state = statePredict[1]
predict = statePredict[2]
predictions = predict{inputs=inputs}

-- determine accuracy
print('index target prediction')
nCorrect = 0
for i = 1, nPatients do
   local isCorrect = targets[i] == predictions[i]
   print(string.format('%3d %d %d %s',
                       i, targets[i], predictions[i],
                       ifelse(isCorrect, ' ', 'wrong')))
   if isCorrect then
      nCorrect = nCorrect + 1
   end
end
print('nCorrect = ' .. nCorrect)
print('accuracy = ' .. nCorrect / nPatients)

-- test results: should have non decreasing probabilities of death
lastDeathProb = 0
print('predictions for each score')
for s = 0, 41 do
   local inputs = torch.Tensor(1,1)
   inputs[1][1] = s
   local predictions, probabilities = predict{inputs=inputs}
   local odr = observedDeathRate(s)
   local deathProb = probabilities[1][1]
   if odr then
      print(string.format('score %2d prediction %d prob death %f ' .. 
                          'actual death rate %f',
                          s, predictions[1], deathProb, odr))
   else
      print(string.format('score %2d prediction %d prob death %f',
                          s, predictions[1], deathProb))
   end
   assert(deathProb >= lastDeathProb)
   lastDeathProb = deathProb
end
   
print('ok logisticRegression_rtest5')


