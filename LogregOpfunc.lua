-- LogregOpfunc.lua
-- opfunc for weighted logistic regression
-- this implementation does NOT use the nn package

if false then
   -- API overview
   of = LogregOpfunc(X, y, s, nClasses, lambda)
   flatParameters = of:initialParameters()
   num, info = of:loss(flatParameters)
   tensor = of:gradient(flatParameters, info)
   num, tensor = of:lossGradient(flatParameters)
end

require 'augment'
require 'ifelse'
require 'keyboard'
require 'kroneckerProduct'
require 'nn'
require 'torch'

torch.class('LogregOpfunc')

function LogregOpfunc:__init(X, y, s, nClasses, lambda)
   local verboseLevel = 1
   local vp = makeVp(verboseLevel, 'LogregOpfunc:__init')
   vp(1, 'X', X, 'y', y, 's', s, 'nClasses', nClasses, 'lambda', lambda)
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
   assert(lambda) -- make sure all parameters were supplied
   
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)
   self.nUserParameters = (nClasses - 1) * (self.nFeatures + 1)

   if verboseLevel > 0 then
      for k, v in pairs(self) do
         vp(1, 'self.' .. k, tostring(v))
      end
   end
end


-- return flat parameters called theta in the API
function LogregOpfunc:initialTheta() 
   local theta = torch.Tensor(self.nUserParameters)
   local stdv = 1 / math.sqrt(self.nFeatures) -- mimic Torch's nn.Linear
   theta:uniform(-stdv, stdv)
   return theta
end

-- return loss and probs at parameters
function LogregOpfunc:loss(theta, implementation)
   local vp = makeVp(1, 'LogregOpfunc:loss')
   vp(1, 'theta', theta, 'implementation', implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_loss1(theta)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end

-- NOTE: parameters are not necessarily mapped to the storage of self.W
-- Ideas for speedup:
-- 1. pre-allocate all the matrices, in order to avoid garbage collection
-- 2. determine logits in one computation: W * X'
-- 3. bypass calls to vp()
-- 4. use results form of Tensor arithmetics: op(result, p1, p2, ...)

-- loss1: simple but has risk of numeric overflow
-- l(theta) = \sum_i \sum_j y_j^i s^i log mu_j^i
-- OVERFLOW CALCULATIONS: for the problems of interest
--   nSamples <= 120
--   nClasses <= 25
-- avg prob = 1 / (120 * 25) = 1/ 3000
-- log (avg prob) ~= -8
-- l(theta) <= nSamples * nClasses * log(avg prob) = -24000
-- HENCE, risk of overflow is very low for use cases planned
function LogregOpfunc:_loss1(theta)
   local vp = makeVp(2, 'LogregOpfunc:_loss1')
   vp(1, 'theta', theta)
   assert(theta:nDimension() == 1 and theta:size(1) == self.nUserParameters)

   local biases, weights = _structureTheta(theta, self.nClasses, self.nFeatures)
   local scores = _scores(self.X, biases, weights)
   local probs = _probabilities(scores)
   local logLikelihood = _logLikelihood(self.y, self.s, probs)
   local regularizer = _regularizer(weights)
   local loss = - logLikelihood + self.lambda * regularizer

   
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probs

   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end

-- parse biases and weights from the flat parameters theta
-- ARGS
-- theta     : 1D Tensor size (nClasses - 1) x (nFeatures + 1)
-- RETURNS
-- biases    : 1D Tensor size nClasses
-- weights   : 1D Tensor size nClasses x nFeatures
function LogregOpfunc:_structureTheta(theta)
   local biases = 
      torch.Tensor(theta:storage(), 1, 
                   self.nClasses - 1, self.nFeatures + 1)
   local weights = 
      torch.Tensor(theta:storage(), 2, 
                   self.nClasses - 1, self.nFeatures + 1, 
                   self.nFeatures, 1)
   return biases, weights
end


-- compute scores matrix where (scores)_j^i = w_j^T x^i
-- NOTE: perhaps be converted to a single matrix multiplication
-- ARGS
-- X       : 2D Tensor size nSamples x nFeatures
-- biases  : 1D Tensor size nClasses
-- weights : 2D Tensor size nClasses x nFeatures
-- RETURNS
-- scores  : 2D Tensor size nClasses x nFeatures
local function _scores(X, biases, weights)
   local vp = makeVp(2, '_scores')
   local nSamples = X:size(1)
   local nClasses = biases:size(1) + 1
   local scores = torch.Tensor(nSamples, nClasses)
   for i = 1, nSamples do
      for c = 1, nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], X[i])
      end
      scores[i][nClasses] = 0
   end

   -- vectorized version
   if false then
      -- this code is broken
      vp(2, 'X', X, 'weights', weights)
      local product = torch.mm(X, weights:t())
      vp(2, 'product', product)
      local biasesMatrix = torch.Tensor(biases:storage(), 1, nSamples, 1, nClasses, 0)
      vp(2, 'biases', biases, 'biasesMatrix', biasesMatrix)   
      scores2 = biasesMatrix + product
      vp(2, 'scores2', scores2, 'scores', scores)
      stop()
   end

   return scores
end

local function _scores_test()
   local X = torch.Tensor{{10, 20}, {30, 40}}
   local biases = torch.Tensor{1, 2}
   local weights = torch.Tensor{{3, 4}, {5, 6}}
   local scores = _scores(X, biases, weights)
   assert(scores:nDimension() == 2)
   assert(scores:size(1) == 2)
   assert(scores:size(2) == 3)

   assert(scores[1][1] == 1 + 3 * 10 + 4 * 20)
   assert(scores[1][2] == 2 + 5 * 10 + 6 * 20)
   assert(scores[1][3] == 0)

   assert(scores[2][1] == 1 + 3 * 30 + 4 * 40)
   assert(scores[2][2] == 2 + 5 * 30 + 6 * 40)
   assert(scores[2][3] == 0)
end

_scores_test()




-- convert scores to probabilities
-- by taking exp and normalizing over each row
-- ARGS;
-- scores : 2D Tensor size nFeatures x nClasses
-- RETURNS
-- probs  : 2D Tensor size nFeatures x nClasses
--          prob[i][j] == probability sample i is in class j
local function _probabilities(scores)
   local nSamples = scores:size(1)
   local nClasses = scores:size(2)
   local unnormalizedProbabilities = scores:exp() 
   local rowsums = torch.sum(unnormalizedProbabilities, 2)
   local rowsumMatrix = torch.Tensor(rowsums:storage(), 1, nSamples, 1, nClasses, 0)
   local probs = torch.cdiv(unnormalizedProbabilities, rowsumMatrix)
   return probs
end

local function _probabilities_test()
   local vp = makeVp(0, _probabilities_test)

   local scores = torch.Tensor{{0, 0, 0}, {0, 0, 0}}
   local probs = _probabilities(scores)
   vp(1, 'scores', scores, 'probs', probs)
   assert(probs:nDimension() == scores:nDimension())
   assert(probs:size(1) == scores:size(1))
   assert(probs:size(2) == scores:size(2))
   assertEq(probs[1], torch.Tensor{.3333, .3333, .3333}, .0001)
   assertEq(probs[2], torch.Tensor{.3333, .3333, .3333}, .0001)

   local scores = torch.Tensor{{1, 0}, {2, 0}}
   local probs = _probabilities(scores)
   assert(probs:nDimension() == scores:nDimension())
   assert(probs:size(1) == scores:size(1))
   assert(probs:size(2) == scores:size(2))
   assertEq(probs[1][1], .73, .01)
   assertEq(probs[2][1], .88, .01)
end

_probabilities_test()

-- log(likelihood) = sum_i sum_j y_j^i s^i log mu_j^i
-- ARGS
-- y             : 1D Tensor size nSamples, class numbers in {1, 2, ..., nClasses}
-- s             : 1D Tensor size nSamples, salience (== importance)
-- probs         : 2D Tensor of size nFeatures x nClasses
-- RETURNS
-- logLikelihood : number, log of probabiity of the data
local function _logLikelihood(y, s, probs)
   local vp = makeVp(2, '_logLikelihood')
   vp(1, 'probs', probs)
   local logProbs = torch.log(probs)
   
   local nSamples = probs:size(1)
   local nClasses = probs:size(2)

   local logLikelihood = 0
   for i = 1, nSamples do
      logLikelihood = logLikelihood + s[i] * logProbs[i][y[i]]
   end

   return logLikelihood
end

local function _logLikelihood_test()
   local vp = makeVp(2, '_logLikelihood_test')
   local y = torch.Tensor{1, 3}
   local s = torch.Tensor{.1, .5}
   local probs = torch.Tensor{{.5, .4, .1}, {.1, .2, .7}}
   local logLikelihood = _logLikelihood(y, s, probs)
   vp(2, 'logLikelihood', logLikelihood)
   assertEq(logLikelihood, math.log(.5 ^ .1 * .7 ^ .5), .0001)
end

_logLikelihood_test()


-- regularizer
local function _regularizer(weights)
   local squaredWeights = torch.cmul(weights, weights)
   local sumSquaredWeights = torch.sum(squaredWeights)
   local regularizer =  sumSquaredWeights
   return regularizer
end

local function _regularizer_test()
   local weights = torch.Tensor{{1,2},{3, 4}}
   local regularizer = _regularizer(weights)
   assertEq(regularizer, 1^2 + 2^2 + 3^2 + 4^2, .00001)
end

_regularizer_test()

-- loss2: avoid numeric underflow
-- optimized for debugging
function LogregOpfunc:_loss2(parameters)
   local vp = makeVp(0, '_loss2')
   vp(1, 'parameters', parameters)
   local biases = 
      torch.Tensor(parameters:storage(), 1, 
                   self.nClasses - 1, self.nFeatures + 1)
   vp(2, 'biases', biases)
   local weights = 
      torch.Tensor(parameters:storage(), 2, 
                   self.nClasses - 1, self.nFeatures + 1, 
                   self.nFeatures, 1)
   vp(2, 'weights', weights)
   
   -- compute scores matrix where (scores)_j^i = w_j^T x^i
   -- NOTE: can be converted to a single matrix multiplication
   vp(1, 'self.X', self.X)
   local scores = torch.Tensor(self.nSamples, self.nClasses)
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end
   vp(2, 'scores', scores)
   
   -- compute the loss using the scores directly
   local loss = 0
   for i = 1, self.nSamples do
      local c = self.y[i]
      local term1 = self.s[i] * score[i][c]
      local term2 = 0
      for j = 1, self.nClasses do
         term2 = term2 + math.exp(score[i][j])
      end
      loss = loss + term1 + math.log(term2)
   end

   -- regularizer
   local squaredWeights = torch.cmul(weights, weights)
   local sumSquaredWeights = torch.sum(squaredWeights)
   vp(2, 'sumSquaredWeights', sumSquaredWeights)
   local regularizer = self.lambda * sumSquaredWeights
   vp(2, 'self.lambda', self.lambda, 'regularizer', regularizer)
   local loss = -sum + regularizer
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probs
   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end

-- loss3: vectorized version of loss2
-- optimized for debugging
function LogregOpfunc:_loss3(parameters)
   local vp = makeVp(0, '_loss3')
   vp(1, 'parameters', parameters)
   local biases = 
      torch.Tensor(parameters:storage(), 1, 
                   self.nClasses - 1, self.nFeatures + 1)
   vp(2, 'biases', biases)
   local weights = 
      torch.Tensor(parameters:storage(), 2, 
                   self.nClasses - 1, self.nFeatures + 1, 
                   self.nFeatures, 1)
   vp(2, 'weights', weights)
   
   -- compute scores matrix where (scores)_j^i = w_j^T x^i
   -- NOTE: can be converted to a single matrix multiplication
   vp(1, 'self.X', self.X)
   local scores = torch.Tensor(self.nSamples, self.nClasses)
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end
   vp(2, 'scores', scores)
   
   -- compute probabilities
   local logits = scores:exp()
   local rowsums = torch.sum(logits, 2)
   vp(2, 'logits', logits, 'rowsums', rowsums)
   local rowsumMatrix = torch.Tensor(rowsums:storage(), 1, self.nSamples, 1, self.nClasses, 0)
   vp(2, 'rowsumMatrix', rowsumMatrix)
   local probs = torch.cdiv(logits, rowsumMatrix)
   vp(2, 'probs', probs)
   local logProbs = torch.log(probs)
   vp(2, 'logProbs', logProbs)

   -- compute log likelihood salience-weighted
   local sum = 0
   for i = 1, self.nSamples do
      sum = sum + logProbs[i][self.y[i]] * self.s[i]
   end
   vp(2, 'log likelihood salience weighted', sum)

   -- regularizer
   local squaredWeights = torch.cmul(weights, weights)
   local sumSquaredWeights = torch.sum(squaredWeights)
   vp(2, 'sumSquaredWeights', sumSquaredWeights)
   local regularizer = self.lambda * sumSquaredWeights
   vp(2, 'self.lambda', self.lambda, 'regularizer', regularizer)
   local loss = -sum + regularizer
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probs
   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end


-- return gradient at parameters and probs
-- version 1: straight from book, not vectorized
function LogregOpfunc:_gradient1(parameters, info)
   local vp = makeVp(0, 'LogregOpfunc:gradient')
 --- loss1: super-clear implemenation, meant to be easy to read
-- optimized for debugging
function LogregOpfunc:_loss1(parameters)
   local vp = makeVp(0, 'loss1')
   vp(1, 'parameters', parameters)
   local biases = 
      torch.Tensor(parameters:storage(), 1, 
                   self.nClasses - 1, self.nFeatures + 1)
   vp(2, 'biases', biases)
   local weights = 
      torch.Tensor(parameters:storage(), 2, 
                   self.nClasses - 1, self.nFeatures + 1, 
                   self.nFeatures, 1)
   vp(2, 'weights', weights)
   
   -- compute scores matrix where (scores)_j^i = w_j^T x^i
   -- NOTE: can be converted to a single matrix multiplication
   vp(1, 'self.X', self.X)
   local scores = torch.Tensor(self.nSamples, self.nClasses)
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end
   vp(2, 'scores', scores)
   
   -- compute probabilities
   local logits = scores:exp()
   local rowsums = torch.sum(logits, 2)
   vp(2, 'logits', logits, 'rowsums', rowsums)
   local rowsumMatrix = torch.Tensor(rowsums:storage(), 1, self.nSamples, 1, self.nClasses, 0)
   vp(2, 'rowsumMatrix', rowsumMatrix)
   local probs = torch.cdiv(logits, rowsumMatrix)
   vp(2, 'probs', probs)
   local logProbs = torch.log(probs)
   vp(2, 'logProbs', logProbs)

   -- compute log likelihood salience-weighted
   local sum = 0
   for i = 1, self.nSamples do
      sum = sum + logProbs[i][self.y[i]] * self.s[i]
   end
   vp(2, 'log likelihood salience weighted', sum)

   -- regularizer
   local squaredWeights = torch.cmul(weights, weights)
   local sumSquaredWeights = torch.sum(squaredWeights)
   vp(2, 'sumSquaredWeights', sumSquaredWeights)
   local regularizer = self.lambda * sumSquaredWeights
   vp(2, 'self.lambda', self.lambda, 'regularizer', regularizer)
   local loss = -sum + regularizer
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probs
   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end

-- loss1: super-clear implemenation, meant to be easy to read
-- optimized for debugging
function LogregOpfunc:_loss2(parameters)
   local vp = makeVp(0, 'loss1')
   vp(1, 'parameters', parameters)
   local biases = 
      torch.Tensor(parameters:storage(), 1, 
                   self.nClasses - 1, self.nFeatures + 1)
   vp(2, 'biases', biases)
   local weights = 
      torch.Tensor(parameters:storage(), 2, 
                   self.nClasses - 1, self.nFeatures + 1, 
                   self.nFeatures, 1)
   vp(2, 'weights', weights)
   
   -- compute scores matrix where (scores)_j^i = w_j^T x^i
   -- NOTE: can be converted to a single matrix multiplication
   vp(1, 'self.X', self.X)
   local scores = torch.Tensor(self.nSamples, self.nClasses)
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end
   vp(2, 'scores', scores)
   
   -- compute probabilities
   local logits = scores:exp()
   local rowsums = torch.sum(logits, 2)
   vp(2, 'logits', logits, 'rowsums', rowsums)
   local rowsumMatrix = torch.Tensor(rowsums:storage(), 1, self.nSamples, 1, self.nClasses, 0)
   vp(2, 'rowsumMatrix', rowsumMatrix)
   local probs = torch.cdiv(logits, rowsumMatrix)
   vp(2, 'probs', probs)
   local logProbs = torch.log(probs)
   vp(2, 'logProbs', logProbs)

   -- compute log likelihood salience-weighted
   local sum = 0
   for i = 1, self.nSamples do
      sum = sum + logProbs[i][self.y[i]] * self.s[i]
   end
   vp(2, 'log likelihood salience weighted', sum)

   -- regularizer
   local squaredWeights = torch.cmul(weights, weights)
   local sumSquaredWeights = torch.sum(squaredWeights)
   vp(2, 'sumSquaredWeights', sumSquaredWeights)
   local regularizer = self.lambda * sumSquaredWeights
   vp(2, 'self.lambda', self.lambda, 'regularizer', regularizer)
   local loss = -sum + regularizer
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probs
   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end

  vp(1, 'parameters', parameters, 'info', info, 'self', self)
   local weights = info.weights
   local biases = info.biases
   local probs = info.probs
   local nClassesM1 = self.nClasses - 1
   local result = parameters:clone():zero()
   vp(2, 'initialized result', result)
   for i = 1, self.nSamples do
      local muLessY = torch.Tensor(self.nClasses - 1)
      for c = 1, self.nClasses - 1 do
         muLessY[c] = probs[i][c] - ifelse(self.y[i] == c, 1, 0)
      end
      vp(2, 'probs[i]', probs[i], 'y[i]', self.y[i], 'muLessY', muLessY, 'X[i]', self.X[i])
      
      -- implement kroecker product of error_i x [1, x^i] == grad for i-th observation
      local grad = kroneckerProduct(muLessY, augment(self.X[i]))
      result = result + grad
   end
   vp(2, 'gradient before regularization', result)

   -- add in gradient of regularizer (just the weights, not the biases)
   local sumWeights = torch.sum(info.weights)
   result = result + self.lambda * sumWeights
   return result
end

function LogregOpfunc:gradient(parameters, info, implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_gradient1(parameters, info)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end



  
