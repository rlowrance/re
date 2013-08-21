-- localLogRegNn_test.lua
-- unit test

require 'localLogRegNn'
require 'makeVp'

local vp = makeVp(2, 'tester')
torch.manualSeed(123)

-- return values for test set 1
local function testset1()
   -- class 1 contains: [0 0] and [0 1]
   -- class 2 contains: [1 0]
   -- class 3 contains: [1 1]
   local theta = torch.Tensor{{1, -2, 0, 0, 1, -2}}:t()
   local x = torch.Tensor{{0,0},{0,1},{1,0},{1,1}}
   local y = torch.Tensor{{1, 1, 2, 3}}:t()  -- all correctly classified in training
   local w = torch.Tensor{{1,1,1,1}}:t()     -- same weights
   local nClasses = 3
   local config = {nClasses=nClasses, nDimensions=2,
                   verbose=verbose, checkArg=true}
   return x, y, w
end

local x, y, w = testset1()
local lambda = 0.001

local function t(a, b)
   local tensor = torch.Tensor(1, 2)
   tensor[1][1] = a
   tensor[1][2] = b
   return tensor
end

-- configure localLogRegNn
local config = {maxIterations = 100,
                sgdConfig = {learningRate = 2,
                             learningRateDecay = 1e-2},
                checkGradient = true}
                            
local prediction = localLogRegNn(x, y, w, t(0, 0), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 1)

config.checkGradient = false
local prediction = localLogRegNn(x, y, w, t(0, 1), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 1)

local prediction = localLogRegNn(x, y, w, t(1, 0), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 2)

local prediction = localLogRegNn(x, y, w, t(1, 1), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 3)

-- set the weights for samples in class 1 to huge
w = torch.Tensor{{.48, .48, .01, .01}}:t()

local prediction = localLogRegNn(x, y, w, t(0, 0), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 1)

config.checkGradient = true
local prediction = localLogRegNn(x, y, w, t(0, 1), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction == 1)

config.checkGradient = false
local prediction = localLogRegNn(x, y, w, t(1, 0), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction ~= 2)

local prediction = localLogRegNn(x, y, w, t(1, 1), lambda, config)
vp(1, 'prediction', prediction)
assert(prediction ~= 3)


print('ok localLogRegNn')
