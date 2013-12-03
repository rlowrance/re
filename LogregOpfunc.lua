-- LogregOpfunc.lua
-- opfunc for weighted logistic regression
-- this implementation does NOT use the nn package

if false then
   -- API overview
   of = LogregOpfunc(X, y, s, nClasses, lambda)
   flatParameters = of:initialParameters()
   num, errors = of:loss(flatParameters)
   tensor = of:gradient(flatParameters, errors)
   num, tensor = of:lossGradient(flatParameters)
end

require 'nn'
require 'torch'

torch.class('LogregOpfunc')

function LogregOpfunc:__init(X, y, s, nClasses, lambda)
   local vp = makeVp(2, 'LogregOpfunc:__init')
   vp(1, 'X', X, 'y', y, 's', s, 'nClasses', nClasses, 'lambda', lambda)
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
   
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)
   self.nUserParameters = (nClasses - 1) * (self.nFeatures + 1)
end


-- return flat parameters
function LogregOpfunc:initialParameters()
   local parameters = torch.Tensor(self.nUserParameters)
   local stdv = 1 / math.sqrt(self.nFeatures) -- mimic Torch's nn.Linear
   parameters:uniform(-stdv, stdv)
   return parameters
end


-- flatten the weights and biases
local function flatten(weights, biases)
   local vp = makeVp(2, 'flatten')
   local nElements = weights:nElement() + biases:nElement()
   local result = torch.Tensor(nElements)

   local i = 0
   for rowIndex = 1, weights:size(1) do
      for colIndex = 1, weights:size(2) do
         i = i + 1
         result[i] = weights[rowIndex][colIndex]
      end
   end

   for index = 1, biases:size(1) do
      i = i + 1
      result[i] = biases[index]
   end
   
   vp(1, 'weights', weights, 'biases', biases, 'result', result)
   return result
end

-- structure flat paramters into weights and biases
local function structure(flat)
   local vp = makeVp(2, 'structure')

   local weights = torch.Tensor(self.nClasses, self.nFeatures)
   local i = 0
   for rowIndex = 1, self.nClasses do
      for colIndex = 1, self.nFeatures do
         i = i + 1
         weights[rowIndex][colIndex] = flat[i]
      end
   end

   local biases = torch.Tensor(self.nClasses)
   for index = 1, self.nClasses do
      i = i + 1
      biases[i] = flat[i]
   end

   vp(1, 'flat', flat, 'weights', weights, 'biases', biases)
   return weights, biases
end

-- return loss at parameters; negative log likelihood
-- salience weighted, regularized
-- NOTE: parameters are not necessarily mapped to the storage of self.W
-- Ideas for speedup:
-- 1. pre-allocate all the matrices, in order to avoid garbage collection
-- 2. determine logits in one computation: W * X'
-- 3. bypass calls to vp()

-- loss1: super-clear implemenation, meant to be easy to read
-- optimized for debugging:w
function LogregOpfunc:_loss1(parameters)
   local vp = makeVp(2, 'loss')
   vp(1, 'parameters', parameters)
   local biases = 
      torch.Tensor(parameters:storage(), 1, self.nClasses - 1, self.nFeatures + 1)
   vp(2, 'biases', biases)
   local weights = 
      torch.Tensor(parameters:storage(), 2, self.nClasses - 1, self.nFeatures + 1, self.nFeatures, 1)
   vp(2, 'weights', weights)
   
   -- compute scores
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
   sum = sum + regularizer
   return -sum, probs
end

-- return loss and probs at parameters
function LogregOpfunc:loss(parameters, implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_loss1(parameters)
   else
      error('bad implemenation: ' .. tostring(implementation))
   end
end

-- return gradient at parameters and probs
function LogregOpfunc:gradient(parameters, probs)
   local vp = makeVp(2, 'LogregOpfunc:gradient')
   vp(1, 'parameters', parameters, 'probs', probs)
   local result = gradient:clone():zero()
   vp(2, 'initialized result', result)
   for i = 1, self.nSamples do
      local mu_i = probs[i]
      local y_i = torch.Tensor(self.nClasses - 1):zero()
      if self.y[i] ~= self.nClasses then
         y_i[self.y[i]] = 1
      end
      vp(2, 'mu_i', mu_i, 'y_i', y_i)
      local errors_i = mu_i - y_i
      vp(2, 'errors_i', errors_i)
      -- implement kroecker product of error_i x [1, x^i]
      stop()
   end
   -- add in gradient of regularizer
end





  
