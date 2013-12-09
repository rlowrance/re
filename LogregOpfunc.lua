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
require 'printAllVariables'
require 'printTableVariable'
require 'printVariable'
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
-- RETURNS
-- theta : 1D Tensor size (nClasses -1) * (nFeatures + 1)
function LogregOpfunc:initialTheta() 
   local theta = torch.Tensor(self.nUserParameters)
   local stdv = 1 / math.sqrt(self.nFeatures) -- mimic Torch's nn.Linear
   theta:uniform(-stdv, stdv)
   return theta
end

-- return loss and probs at parameters
-- ARGS
-- theta          : 1D Tensor size (nClasses - 1) * (nFeatures + 1)
-- implementation ; option number, default 1
-- RETURNS
-- loss           : number, regularized negative log likelihood of theta (NLL)
-- info           : table needed for call to method gradient
--                  the table avoids recomputing values in both the loss and
--                  gradient methods
function LogregOpfunc:loss(theta, implementation)
   local vp = makeVp(0, 'LogregOpfunc:loss')
   vp(1, 'theta', theta, 'implementation', implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_loss1(theta)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end

-- return gradient at parameters 
-- ARGS
-- theta    : 1D Tensor size (nClasses - 1) * (nFeatures + 1)
-- info     : table from the loss methods
-- RETURNS
-- gradient : 1D Tensor size (nClasses - 1) * (nFeatures + 1)
function LogregOpfunc:gradient(theta, info, implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_gradient1(theta, info)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end


-- PRIVATE METHODS

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
   local vp = makeVp(0, 'LogregOpfunc:_loss1')
   vp(1, 'theta', theta)
   assert(theta:nDimension() == 1 and theta:size(1) == self.nUserParameters)

   local biases, weights = self:_structureTheta(theta)
   local scores = self:_scores(biases, weights)
   local probabilities = self:_probabilities(scores)
   local logLikelihood = self:_logLikelihood(probabilities)
   local regularizer = self:_regularizer(weights)
   local loss = - logLikelihood + self.lambda * regularizer

   
   local info = {}
   info.weights = weights
   info.biases = biases
   info.probs = probabilities

   vp(1, 'loss', loss, 'info.probs', info.probs)
   return loss, info
end

-- parse biases and weights from the flat parameters theta
-- ARGS
-- theta     : 1D Tensor size (nClasses - 1) x (nFeatures + 1)
-- RETURNS
-- biases    : 1D Tensor size (nClasses - 1)
-- weights   : 1D Tensor size (nClasses - 1) x nFeatures
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
-- biases  : 1D Tensor size (nClasses - 1)
-- weights : 2D Tensor size (nClasses - 1) x nFeatures
-- RETURNS
-- scores  : 2D Tensor size nSamples x nClasses
function LogregOpfunc:_scores(biases, weights)
   local scores = torch.Tensor(self.nSamples, self.nClasses)
   
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end

   return scores
end




-- convert scores to probabilities
-- by taking exp and normalizing over each row
-- ARGS;
-- scores : 2D Tensor size nFeatures x nClasses
-- RETURNS
-- probs  : 2D Tensor size nFeatures x nClasses
--          prob[i][j] == probability sample i is in class j
function LogregOpfunc:_probabilities(scores)
   local unnormalizedProbabilities = scores:exp() 
   local rowsums = torch.sum(unnormalizedProbabilities, 2)
   local rowsumMatrix = torch.Tensor(rowsums:storage(), 1, self.nSamples, 1, self.nClasses, 0)
   local probs = torch.cdiv(unnormalizedProbabilities, rowsumMatrix)
   return probs
end


-- log(likelihood) = sum_i sum_j y_j^i s^i log mu_j^i
-- ARGS
-- probs         : 2D Tensor of size nFeatures x nClasses
-- RETURNS
-- logLikelihood : number, log of probabiity of the data
function LogregOpfunc:_logLikelihood(probs)
   local vp = makeVp(2, '_logLikelihood')
   vp(1, 'probs', probs)
   local logProbs = torch.log(probs)
   
   local logLikelihood = 0
   for i = 1, self.nSamples do
      logLikelihood = logLikelihood + self.s[i] * logProbs[i][self.y[i]]
   end

   return logLikelihood
end


-- regularizer
function LogregOpfunc:_regularizer(weights)
   local squaredWeights = torch.cmul(weights, weights)
   local regularizer = torch.sum(squaredWeights)
   return regularizer
end



-- return gradient at parameters and probs
-- version 1: straight from book, not vectorized
-- meant to be easy to read
function LogregOpfunc:_gradient1(theta, info)
   local gradient = theta:clone():zero()
   for i = 1, self.nSamples do
      gradient = gradient + self:_gradient_i(i, info)
   end

   gradient = gradient + self:_regularizerGradient(theta)
   return gradient
end

-- determine gradient at i-th observation
-- ref: Murphy, p. 253
function LogregOpfunc:_gradient_i(i, info)
   local mu = info.probs[i]
   local y = torch.Tensor(self.nClasses):zero()
   y[self.y[i]] = 1
   local muLessY = mu - y

   -- drop last element of muLessY
   local muLessYShort = torch.Tensor(muLessY:storage(), 1, self.nClasses - 1, 1)

   printAllVariables() printTableVariable('self')
   local gradient_i = kroneckerProduct(muLessYShort, self.X[i])
   printVariable('gradient_i')
   assert(gradient_i:size(1) == self.nUserParameters)

   error('check _gradient_i values')

   return gradient_i
end
   
function LogregOpfunc:_regularizerGradient(theta)
   local biases, weights = self:_structureTheta(theta)
   local regularizerGradient = theta:clone():zero()
   for c = 1, self.nClasses - 1 do
      for d = 1, self.nFeatures do
         regularizerGradient[(c - 1) * self.nFeatures + d] = 2 * self.lambda * weights[c][d]
      end
   end
   return regularizerGradient
end


  
