-- ModelLogisticRegression.lua
-- weighted logistic regression

if false then
   -- API overview
   lambda = 0.001
   nClasses = 14
   m = ModelLogisticRegression(lambda, nClasses)

   m:fit(X,y,s) -- s is a 1D matrix of salience values
   m:predict(X) -- return 1D matrix of class numbers
end

require 'makeVp'
require 'nn'
require 'Random'
require 'torch'

torch.class('ModelLogisticRegression')

-- construct model
-- ARGS
-- lambda   : number, importance of L2 regularizer
-- nClasses : number
-- RETURNS
-- self     : instance of LogisticRegression
function ModelLogisticRegression:__init(lambda, nClasses)
   assert(lambda >= 0)
   assert(nClasses >=0)
   self.lambda = lambda
   self.nClasses = nClasses
end

-- fit parameters using stochastic gradient descent, L2 regularizer
-- ARGS
-- X : 2D matrix of size [nSamples, nFeatures]
-- y : 1D matrix of size [nSamples]
-- s : 1D matrix of size [nSamples]; saliences (= importance)
function ModelLogisticRegression:fit(X, y, s)
   local vp = makeVp(2, 'LogisticRegression:fit')
   assert(X)
   assert(y)
   assert(s)

   local nSamples = X:size(1)
   local nFeatures = X:size(2)

   if self.W == nil then
      self.W = torch.rand(self.nClasses, nFeatures)
      for i = 1, nFeatures do -- weights for last class fixed at 0
         self.W[self.nClasses][i] = 0
      end
   end
   vp(2, 'self.W', self.W)

   local scores = torch.exp(torch.mm(self.W, X:t()))
   vp(2, 'scores', scores)

   local uProb = torch.sum(scores, 2)
   vp(2, 'uProb', uProb)
   local sumProb = torch.sum(uProb)
   local prob = torch.div(uProb, sumProb)
   vp(2, 'prob', prob)
   stop()

   local model = nn.Sequential()
   model:add(nn.Linear(nFeatures, self.nClasses))
   model:add(nn.LogSoftMax())

   local criterion = nn.ClassNLLCriterion()

   local modelParameters, modelGradient = model:getParameters()

   -- determine if X can be a mini batch
   local prediction = model:forward(X)
   vp(2, 'prediction', prediction)
   vp(2, 'criterion:forward(prediction, y)', criterion:forward(prediction, y))
   
   -- by hand without nn
   local parameters = model:getParameters()
   vp(2, 'parameters', parameters)
   local scores = torch.mul(parameters, X:t())
   vp(2, 'scores')
   stop()

   local loss = criterion:forward(prediction, y) * s  -- importance weighted
   local gradCriterion = criterion:backward(prediction, y) * s
   model:zeroGradParameters()
   model:backward(inpput, gradCriterion) -- set modelParameters and modelGradient
   vp(2, 'modelParameters', modelParameters, 'modelGradient', modelGradient)
   stop()
  
   -- determine timing for forward-backward passes
end

-- test code
torch.manualSeed(123)

local nSamples = 10
local nFeatures = 8
local nClasses = 3

local X = torch.rand(nSamples, nFeatures)
local y = Random():integer(nSamples, 1, nClasses)
local s = Random():uniform(nSamples, 0, 1)
   
local lr = ModelLogisticRegression(0.001, nClasses)
lr:fit(X, y, s)
stop('write more')

