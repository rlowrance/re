-- modelLogreg_test.lua

require 'makeVp'
require 'modelLogreg'

torch.manualSeed(123456)

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- return values for test set 1
local function testset1()
   -- class 1 contains: [0 0] and [0 1]
   -- class 2 contains: [1 0]
   -- class 3 contains: [1 1]
   local theta = torch.Tensor{{1, -2, 0, 0, 1, -2}}:t()
   local X = torch.Tensor{{0,0},{0,1},{1,0},{1,1}}
   local y = torch.Tensor{{1, 1, 2, 3}}:t()  -- all correctly classified
   local w = torch.Tensor{{1,1,1,1}}:t()     -- same weights
   local nClasses = 3
   local config = {nClasses=nClasses, nDimensions=2,
                   verbose=verbose, checkArg=true}
   return theta, X, y, w, config
end

-- test fit function
local theta, X, y, w, config = testset1()
local lambda = 0.001
local thetaStar, values = modelLogreg.fit(config, X, y, w, lambda)
vp(1, 'thetaStar', thetaStar, 'values from fit', values)
local predictions = modelLogreg.predict(config, thetaStar, X)
vp(1, 'thetaStar', thetaStar, 'values', values, 'predictions', predictions)
assert(values ~= nil)
for i = 1, X:size(1) do
   assert(predictions[i][1] == y[i][1])  -- perfect predictions
end

-- simple example
local nClasses = 2
local theta = torch.Tensor{{.5, .3333}}:t()
local X = torch.Tensor{{1}}
local y = torch.Tensor{{2}}:t()
local w0 = torch.Tensor{{0}}:t()
local w1 = torch.Tensor{{1}}:t()
local w3 = torch.Tensor{{3}}:t()
local config = {nClasses=2, nDimensions=1, verbose=verbose, checkArgs=true}
local eps = .001
local thetaPlus = theta:clone()
thetaPlus[1] = thetaPlus[1] +  eps
local _, probs = modelLogreg.predict(config, theta, X)
vp(1, 'probs', probs)
assertEq(probs, torch.Tensor{{.6971, .3029}}, .0001)
local _, probsPlus = modelLogreg.predict(config, thetaPlus, X)
vp(1, 'probsPlus', probsPlus)
--assertEq(probsPlus, torch.Tensor{{.7178, .2822}}, .0001)
local function test(w)
   local lambda = 0
   local gradient = 
      modelLogreg.gradient(config, theta, X, y, w1, lambda)
   local gradientFd = 
      modelLogreg.fdGradient(config, eps, theta, X, y, w1, lambda)
   vp(1, 'w', w, 'gradient', gradient, 'gradientFd', gradientFd)
end
test(w1)
test(w0)
test(w3)

-- initialTheta
local theta = modelLogreg.initialTheta(config)
vp(3, 'theta (2,1)', theta)
assert(theta:size(1) == 2)
assert(theta:size(2) == 1)

local config2 = {nClasses=10, nDimensions=12}
local theta = modelLogreg.initialTheta(config2)
vp(3, 'theta (10,12)', theta)
assert(theta:size(1) == 9 * 13)
assert(theta:size(2) == 1)

-- test structureTheta
local nClasses = 3
local nDimensions = 2
local theta = torch.Tensor{{10, -1, 1, 0, -2, 3}}:t()
local config = {nClasses = nClasses, nDimensions = 2,
                verbose=verbose, checkArgs=true}
local biases, weights = modelLogreg.structureTheta(config, theta)
assertEq(biases, torch.Tensor{{10}, {0}, {0}}, 0)
assertEq(weights, torch.Tensor{{-1,1},{-2,3}, {0,0}}, 0)

-- unstructureTheta
--[[
local newTheta = modelLogreg.unstructureTheta(biases, weights)
vp(1, 'newTheta', newTheta)
assertEq(theta, newTheta, 0)
   ]]


-- compare gradient to fdGradient
local theta, X, y, w, config = testset1()
local lambda = 0
local gradient = modelLogreg.gradient(config, theta, X, y, w, lambda)
local epsilon = 1e-3
local fdGradient = modelLogreg.fdGradient(config,
                                          epsilon,
                                          theta, X, y, w, lambda)
vp(2, 'gradient', gradient, 'fdGradient', fdGradient)
assertEq(gradient, fdGradient, .0001)

-- test predict
local theta, X, y, w, config = testset1()
local estimates, probs = modelLogreg.predict(config, theta, X)
vp(1, 'estimates', estimates, 'probs', probs)
assertEq(estimates, torch.Tensor{{1,1,2,3}}:t(), 0)
assertEq(probs, 
         torch.Tensor{{.58, .21, .21},
                      {.71,.04,.26},
                      {.09,.67,.24},
                      {.21,.21,.58}}, 
         .01)
-- each row of probs sums to 1
-- estimates are for the largest prob in each row
for i = 1, X:size(1) do
   assertEq(torch.sum(probs[i]), 1, .0001)
   vp(2, 'probs[i,:]', probs:select(1, i))
   vp(2, 'y[i]', y[i])
   assert(y[i][1] == maxIndex(probs:select(1, i)))
end

-- test cost
local theta, X, y, w, config = testset1()
--local estimates, probs = modelLogreg.predict(nClasses, theta, X)
--local biases, weights = modelLogreg.structureTheta(nClasses, 2, theta)
local costNoreg = modelLogreg.cost(config, theta, X, y, w, 0)
vp(1, 'costNoreg', costNoreg)
assertEq(costNoreg, 1.9427, .1)
local costReg = modelLogreg.cost(config, theta, X, y, w, 1)
vp(1, 'costReg', costReg)
--assertEq(costReg, 1.9427 + 1 * (4 + 0 + 1 + 4), .1)
assert(costNoreg + 9 == costReg)

-- test gradient
local theta, X, y, w, config = testset1()
-- redefine X and y to have one row
local XX = torch.Tensor(1, X:size(2))
for d = 1, X:size(2) do
   XX[1][d] = X[1][d]
end
local yy = torch.Tensor(1, 1)
yy[1][1] = y[1][1]
local ww = torch.Tensor(1, 1)
ww[1][1] = w[1][1]
--local estimates, probs = modelLogreg.predict(nClasses, theta, X)
--local biases, weights = modelLogreg.structureTheta(nClasses, 2, theta)
local gradientNoreg = modelLogreg.gradient(config, theta, XX, yy, ww, 0)
vp(1, 'gradientNoreg', gradientNoreg)
assert(gradientNoreg[1][1] ~= 0)
assert(gradientNoreg[2][1] == 0) -- since X[1] = [0 0]
assert(gradientNoreg[3][1] == 0)
assert(gradientNoreg[4][1] ~= 0)
assert(gradientNoreg[5][1] == 0)
assert(gradientNoreg[6][1] == 0)

local gradientReg = modelLogreg.gradient(config, theta, XX, yy, ww, 1)
vp(1, 'graidentReg', gradientReg)
assert(gradientReg[1][1] == gradientNoreg[1][1])
assert(gradientReg[4][1] == gradientNoreg[4][1])
assertEq(gradientReg[2][1], gradientNoreg[2][1] + 2 * theta[2][1], .0001)

-- test costGradient
local theta, X, y, w, config = testset1()

local lambda = 0  
local cost0, g0 = modelLogreg.costGradient(config, theta, X, y, w, lambda)
vp(1, 'cost no reg', cost)
vp(1, 'gradient no reg', g)
vp(1, 'write test')

local lambda = 1
local cost1, g1 = modelLogreg.costGradient(config, theta, X, y, w, lambda)
vp(1, 'cost0', cost0, 'cost1', cost1)
assert(cost1 > cost0)
vp(1, 'g0', g0, 'g1', g1)
local difference = false
for d = 1, g0:size(1) do
   if g0[d][1] ~= g1[d][1] then
      difference = true
   end
end
assert(difference)


-- test set 1
if true then
local theta, X, y, w, config = testset1()
local estimates, probs = modelLogreg.predict(config, theta, X)
vp(2, 'estimates', estimates, 'probs', probs, 'nClassses', nClasses)
assert(probs:dim() == 2 and 
       probs:size(1) == 4 and 
       probs:size(2) == config.nClasses)
assertEq(estimates, torch.Tensor{{1,1,2,3}}:t(), 0)

local wOne = torch.Tensor{{1,1,1,1}}:t()
local costNoReg = modelLogreg.costGradient(config, theta, X, y, wOne, 0)
local likelihood = .5761 * .7054 * .6652 * .5761
vp(2, 'costNoReg', costNoReg, 'liklihood', likelihood)
assertEq(costNoReg, -math.log(likelihood), .01)
local cost Reg = modelLogreg.costGradient(config, theta, X, y, wOne, 1)
assertEq(costReg, costNoReg + (-2)*(-2) + 1 * 1 + (-2)* (-2), .0001)
end

-- check many gradient values
local function testGradientRandomly(nClasses, nDimensions, m, lambda)
   local vp = makeVp(verbose, 'testGradientRandomly')
   vp(1, 
      'nClasses', nClasses, 
      'nDimensions', nDimensions, 
      'm', m, 
      'lambda', lambda)
   local X = torch.rand(m, nDimensions)
   local y = torch.Tensor(m, 1):zero()
   local w = torch.Tensor(m, 1):zero()
   for i = 1, m do
      local rand = 1
      for c = 1, nClasses -1 do
         rand = rand + torch.bernoulli(.5)
      end
      y[i][1] = rand
      if torch.uniform(0,1) < .5 then
         w[i][1] = torch.uniform(0,1)
      end
   end
   local theta = torch.randn((nClasses - 1) * (nDimensions + 1), 1)

   vp(1,
      'nClasses', nClasses,
      'theta', theta,
      'X', X,
      'y', y,
      'w', w,
      'lambda', lambda)

   local config = {nClasses=nClasses, nDimensions=nDimensions,
                   checkArgs=true, verbose=verbose,
                   testGradient=true}
   config.testGradient = false
   local c, g = modelLogreg.costGradient(config, theta, X, y, w, lambda)
   vp(1, 'c', c, 'g', g)
end

for nClasses = 2, 10 do
   local nDimension = 10
   local m = 20 
   for lambda = 0, .1 do
      testGradientRandomly(nClasses, nDimensions, m, lambda)
   end
end

   

print('ok modelLogreg')

