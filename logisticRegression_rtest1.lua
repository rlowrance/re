-- logisticRegression_rtest1.lua
-- test on known problem
-- TODO: test on weighted training points

require 'ifelse'
require 'logisticRegression'
require 'optim'
require 'optim_vsgdfd'      -- self-tuning SGD via Tom Schaul
require 'makeVp'

local verbose = 2
local vp = makeVp(verbose)

torch.manualSeed(123)

local p = 100
local inputs = torch.rand(p, 2)
local targets = torch.Tensor(p)
for i = 1, p do
   if inputs[i][1] < 0.5 then
      if inputs[i][2] < 0.5 then
         targets[i] = 1
      else
         targets[i] = 2
      end
   else
      if inputs[i][2] < 0.5 then
         targets[i] = 3
      else
         targets[i] = 4
      end
   end
end

local nCorrect = 0
local function printData(predictions, probs)
   if verbose >= 2 then 
      print('actuals vs. predictions')
      for i = 1, p do
         local error = ' '
         if predictions[i] ~= targets[i] then
            error = 'error'
         end
         print(string.format('input %0.4f %0.4f target %d predicted %d' .. 
                             ' probs %0.2f %0.2f %0.2f %0.2f %s',
                              inputs[i][1], inputs[i][2], targets[i],
                              predictions[i],
                              probs[i][1], 
                              probs[i][2], 
                              probs[i][3], 
                              probs[i][4],
                              error))
         if targets[i] == predictions[i] then
          nCorrect = nCorrect + 1
        end
       end
   end
end 

--printData()

local parmsSgd = {learningRate=0.1,      -- default (from optim.sgd) is 1e-3
                  learningRateDecay=0}   -- default is 0
local parmsVsgdfd = {verbose=1}
local nEpochs = 100
local state, predict = logisticRegression{inputs=inputs,
                                           targets=targets,
                                           lambda = 0.0,
                                           epochs=nEpochs,
                                           optimFunction=optim.vsgdfd,
                                           optimParams=parmsVsgdfd}

local predictions, probs = predict{inputs=inputs}  -- predict on training data

printData(predictions, probs)

accuracy = nCorrect / p
print('\naccuracy = ', accuracy)
vp(1, 'state.weights', state.weights)
vp(1, 'avg loss by epoch')
for i = 1, 10 do 
  print('epoch ' .. i .. ' avg loss ' .. state.avgLoss[i])
end
for i = nEpochs - 10, nEpochs do
  print('epoch ' .. i .. ' avg loss ' .. state.avgLoss[i])
end
vp(1, 'parms', parms)

-- accuracy should be high
assert(accuracy > .95)
print('ok logisticRegression_rtest1')
