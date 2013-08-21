-- makeModelILLogReg_test.lua
-- see lab book 4/28/2013 for hand calculations

require 'checkGradient'
require 'makeModelILLogReg'
require 'makeVp'

local function assertEq(a, b, tolerance)
   assert(math.abs(a - b) < tolerance)
end

torch.manualSeed(123456)

local verbose = 2
local vp = makeVp(verbose, 'tester')

-- test 1: model and criterion
local inputs = torch.Tensor{{30, -150, 1950},
                            {31, -150, 1950},
                            {30, -151, 1950},
                            {30, -150, 1951}}
local targets = torch.Tensor{1, 2, 1, 3}
local importances = torch.Tensor{.1, .2, .3, .4}
local queryIndex = 0  -- use all samples in eval and gradients function
local regularizerCoefficient = 0.1
local kmPerYear = 1000
local k = 2
local eval, gradients, predict, nParameters, loss, gradient = 
   makeModelILLogReg(inputs,
                     targets,
                     importances,
                     queryIndex,
                     regularizerCoefficient,
                     kmPerYear,
                     k)

 -- test 1: check prediction()
vp(1, 'eval', eval)
vp(1, 'gradients', gradients)
vp(1, 'predict', predict)
vp(1, 'nParameters', nParameters) -- 3 classes, 3 inputs
vp(1, 'loss', loss)
vp(1, 'gradient', gradient)
assert(nParameters == 8)
local parameters = torch.Tensor(nParameters):zero()
local prediction = predict(parameters, inputs[1])
vp(1, 'prediction', prediction)
assertEq(prediction[1], 0.3333, .001)
assertEq(prediction[2], 0.3333, .001)
assertEq(prediction[3], 0.3333, .001)

-- test 2: check loss()
local parameters = torch.Tensor{1, .1, .2, .3, 0, .5, .6, .1}
local l, prediction = loss(parameters,
                           torch.Tensor{1, -1, 2},  -- input
                           1,                       -- target
                           0.1)                     -- importance
vp(1, 'loss', l)
vp(1, 'prediction', prediction)
assertEq(l, 0.2145, 0.0001)
assertEq(prediction[1], 0.6804, .0001)
assertEq(prediction[2], 0.1678, .0001)
assertEq(prediction[3], 0.1518, .0001)

-- test 3: check gradient vs. finite difference version

-- return loss
local input = torch.Tensor{1, -1, 2}
local target = 1
local importances = torch.Tensor{1,1,1,1}  -- also test {.1,.2,.3,.4}
local regularizerCoefficient = 0           -- also test 1e-3
local eval, gradients, predict, nParameters, loss, gradient = 
   makeModelILLogReg(inputs,
                     targets,
                     importances,
                     queryIndex,
                     regularizerCoefficient,
                     kmPerYear,
                     k)

function f(x)
   local l= loss(x, input, target, 0.1)
   return l
end

local parameters = torch.Tensor{1, .1, .2, .3, 0, .5, .6, .1}
local p = predict(parameters, input)
local importance = 1.0  -- also test 0.1
vp(1, 'p', p)
local g = gradient(parameters, p, input, target, importance)
local d, dh = checkGradient(f,
                            parameters,
                            1e-10,         -- epsilon
                            g,            -- gradient
                            false)        -- verbose
vp(1, 'd', d)
vp(1, 'dh', dh)
vp(1, 'g', g)

stop()
                            


stop() 


-- test 3: check gradient


stop()


-- test 2: TO BE DEFINED
vp(1, 'model', model)
local parameters = model:parameters()  -- ties locations
for i = 1, #parameters do
   vp(1, 'parameters[' .. i .. ']', parameters[i])
end

local input = inputs[1]
local target = targets[1]
vp(1, 'input', input)
vp(1, 'target', target)

local prediction = model:forward(input)
vp(1, 'prediction', prediction)
local loss = criterion:forward(prediction, target)
vp(1, 'loss', loss)
model:zeroGradParameters()
local t = criterion(prediction, target)
vp(1, 't', t)
local gradInput = model:backward(prediction, t)
vp(1, 'gradInput', gradInput)
vp(1, 'parameters after all backward', parameters)
local learningRate = .5
model:updateParameters(learningRate)
vp(1, 'parameters after update Parameters', parameters)

stop()