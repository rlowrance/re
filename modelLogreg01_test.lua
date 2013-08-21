-- modelLogreg01_test.lua

require 'assertEq'
require 'ifelse'
require 'makeVp'
require 'modelLogreg01'

local verbose = 2
local vp = makeVp(verbose, 'tester')
local m = modelLogreg01

torch.manualSeed(123)

-- test deconstructTheta
local theta = torch.Tensor{{1,2,3}}:t()
local bias, weights = m.deconstructTheta(theta)
assert(type(bias) == 'number')
assert(bias == 1)
assertEq(weights, torch.Tensor{{2,3}}:t(), 0)

-- test initialTheta
local initialTheta = m.initialTheta(2)
vp(3, 'initialTheta', initialTheta)
assert(initialTheta:dim() == 2)
assert(initialTheta:size(1) == 3)
assert(initialTheta:size(2) == 1)
for d = 1, 3 do
   assert(math.abs(initialTheta[d][1]) <= 1)
end

-- test hypothesis 1
local nParameters = 2
local initialTheta = m.initialTheta(nParameters)
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local probs = m.h(initialTheta, X)
assert(probs:dim() == 2)
assert(probs:size(1) == 4)
assert(probs:size(2) == 1)
for m = 1, 4 do
   local prob = probs[m][1]
   assert(0 <= prob)
   assert(prob <= 1)
end

-- test hypothesis 2
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local probs = m.h(initialTheta, X)
vp(1, 'probs', probs)
assert(probs:dim() == 2)
assert(probs:size(1) == 4)
assert(probs:size(2) == 1)
for m = 1, 4 do
   local prob = probs[m][1]
   assert(0 <= prob)
   assert(prob <= 1)
end

-- test predict
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local estimates, probs = m.predict(theta,X)
vp(3, 'estimates', estimates, 'probs', probs)
assertEq(estimates, torch.Tensor{{1, 0, 1, 1}}:t(), 0)
local tol = 1e-10
assertEq(probs[1][1], 0.5, tol)
assert(probs[2][1] <  0.5)
assert(probs[3][1] >  0.5)
assertEq(probs[4][1], 0.5, tol)

-- test cost and gradient 1: no regularizer, no errors, equal weights
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local y = torch.Tensor{{1, 0, 1, 1}}:t()  -- no errors
local w = torch.Tensor{{1, 1, 1, 1}}:t()  -- equal weights
local lambda = 0                          -- no regularizer
local cost, gradient = m.costGradient(theta, X, y, w, lambda)
vp(1, 'cost', cost, 'gradient', gradient)
assertEq(cost, .5032, .0001)
local gradExpected = torch.Tensor{{-1/4, -.7689/4, -.2311/4}}:t()
assertEq(gradient, gradExpected, 1e-4)

-- test cost and gradient 2: regularizer, no errors, equal weights
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local y = torch.Tensor{{1, 0, 1, 1}}:t()  -- no errors
local w = torch.Tensor{{1, 1, 1, 1}}:t()  -- equal weights
local lambda = 1                          -- regularizer
local mm = X:size(1)
local cost, gradient = m.costGradient(theta, X, y, w, lambda)
vp(1, 'cost', cost, 'gradient', gradient)
local sumThetaSquared = 1*1 + (-1)*(-1) 
--vp(2, 'sumThetaSquared', sumThetaSquared, 'mm', mm)
assertEq(cost, .5032 + ((lambda * sumThetaSquared) / (2 * mm)), .0001)
local gradReg = torch.Tensor{{0, (lambda/mm) * 1, (lambda/mm) * (-1)}}:t()
vp(2, 'gradExpected', gradExpected, 'gradReg', gradReg)
assertEq(gradient, gradExpected + gradReg, 1e-4)

-- test cost and gradient 3: no regularizer, no errors, different weights
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local y = torch.Tensor{{1, 0, 1, 1}}:t()  -- no errors
local w = torch.Tensor{{1, 2, 4, 8}}:t()  -- equal weights
local lambda = 0                          -- no regularizer
local cost, gradient = m.costGradient(theta, X, y, w, lambda)
vp(1, 'cost', cost, 'gradient', gradient)
assertEq(cost, 2.0293, .0002)
-- the expected gradient was computed by the gradient-checking code
local gradExpected = torch.Tensor{{-1.259470, -1.268941, -0.865530}}:t()
assertEq(gradient, gradExpected, 1e-4)

-- test cost and gradient 4: noregularizer, errors in each, equal weights
local theta = torch.Tensor{{0,1,-1}}:t()
local X = torch.Tensor{{0, 0}, {0, 1}, {1, 0}, {1, 1}}
local y = torch.Tensor{{0, 1, 0, 0}}:t()  -- all errors
local w = torch.Tensor{{1, 1, 1, 1}}:t()  -- equal weights
local lambda = 0                          -- regularizer
local mm = X:size(1)
local cost, gradient = m.costGradient(theta, X, y, w, lambda)
vp(1, 'cost', cost, 'gradient', gradient)
local sumThetaSquared = 1*1 + (-1)*(-1) 
--vp(2, 'sumThetaSquared', sumThetaSquared, 'mm', mm)
assertEq(cost, 1.0033, .0001)
--local gradExpected = torch.Tensor{{1/4, .7689/4, .2311/4}}:t()
--assertEq(gradient, gradExpected, 1e-4)

-- test gradient on random values
for test = 1, 10 do
   local mm = 10
   local n = 5
   local theta = torch.rand(n+1, 1)
   local X = torch.rand(mm, n)
   local y = torch.Tensor(mm, 1):fill(1)
   local w = torch.Tensor(mm, 1):fill(1)
   local lambda = torch.rand(1,1)[1][1]
   local cost, gradient = m.costGradient(theta, X, y, y, lambda)
end
-- here if no problems found with gradient

-- test fit
vp(0,'********************')
local mm = 2  -- ALSO FAILS WITH mm = 10
local label = 0
local Exams = torch.Tensor(mm, 2)
local admitted = torch.Tensor(mm, 1)
local weights = torch.Tensor(mm, 1)
for i = 1, mm do
   local mean = ifelse(label==0, 50, 100)
   Exams[i][1] = torch.normal(mean, 10) -- exam1
   Exams[i][2] = torch.normal(mean, 10) -- exam2
   admitted[i][1] = label
   weights[i][1] = 1
   label = ifelse(label == 0, 1, 0)
end
vp(2, 'admitted', admitted)
vp(2, 'weights', weights)

local lambda = 0
local thetaStar = m.fit(Exams, admitted, weights, lambda)
vp(1, 'thetaStar', thetaStar)
local estimates, probs = m.predict(thetaStar, Exams)
local nErrors = 0
for i = 1, Exams:size(1) do
   local estimate = estimates[i][1]
   local actual = admitted[i][1]
   vp(1, string.format('i %d estimate %d actual %d',
                       i, estimates[i][1], admitted[i][1]))
   if estimate ~= actual then
      nErrors = nErrors + 1
   end
end
vp(1, 'nErrors', nErrors)


error('write tests')

print('ok modelLogreg01')