-- LogisticRegression.lua
-- weighted logistic regression

if false then
   -- API overview
   m = LogisticRegression(lambda=0.001, nClasses=14)

   m:fit(X,y,s) -- s is a 1D matrix of salience values
   m:predict(X) -- return 1D matrix of class numbers
end

require 'makeVp'
require 'torch'

torch.class('LogisticRegression')

-- construct model
-- ARGS
-- lambda   : number, importance of L2 regularizer
-- nClasses : number
-- RETURNS
-- self     : instance of LogisticRegression
function LogisticRegression:__init(lambda, nClasses)
   assert(lambda >= 0)
   assert(nClasses >=0)
   self.lambda = lambda
   self.nClasses = nClasses
end

-- fit parameters using stochastic gradient descent
-- ARGS
-- X : 2D matrix of size [nSamples, nFeatures]
-- y : 1D matrix of size [nSamples]
-- s : 1D matrix of size [nSamples]; saliences (= importance)
function LogisticRegression:fit(X, y, s)
   local vp = makeVp(2, 'LogisticRegression:fit')
   assert(X)
   assert(y)
   assert(s)

   local nSamples = X:size[1]

   local model = nn.Sequential()
   model:add(nn.Linear(nFeatures, self.nClasses)
   model:add.LogSoftMax())

   local criterion = nn.ClassNllCriterion()

   local modelParameters, modelGradient = model:getParameters()

   -- determine if X can be a mini batch
   local prediction = model:forward(X)
   local loss = criterio:forard(prediction, target) * s  -- importance weighted
   local gradCriterion = criterion:backward(prediction, target) * s
   model:zeroGradParameters()
   model:backward(inpput, gradCriterion) -- set modelParameters and modelGradient
   vp(2, 'modelParameters', modelParameters, 'modelGradient', modelGradient)
   stop()
  
   -- determine timing for forward-backward passes
end

-- test code
local X = torch.rand(10, 8)
local y = 

   

