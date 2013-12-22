-- LogregOpfunc.lua
-- opfunc for weighted logistic regression
-- this implementation does NOT use the nn package

if false then
   -- API overview
   of = LogregOpfunc(X, y, s, nClasses, lambda)
   flatParameters = of:initialTheta()
   num, lossInfo = of:loss(flatParameters)
   tensor = of:gradient(lossInfo)
end

require 'augment'
require 'ifelse'
require 'keyboard'
require 'kroneckerProduct'
require 'nn'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'printVariable'
require 'torch'

torch.class('LogregOpfunc')

-- CONSTRUCTOR

function LogregOpfunc:__init(X, y, s, nClasses, lambda)
   local vp, verboseLevel = makeVp(0, 'LogregOpfunc:__init')
   vp(1, 'X', X, 'y', y, 's', s, 'nClasses', nClasses, 'lambda', lambda)
   self.X = X
   self.y = y
   self.s = s
   self.nClasses = nClasses
   self.lambda = lambda
   assert(lambda) -- make sure all parameters were supplied
   
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)
   --printVariable('X') printTableVariable('self')
   assert(self.nSamples) -- detect some problems with argument X
   assert(self.nFeatures)
   self.nUserParameters = (self.nClasses - 1) * (self.nFeatures + 1)

   -- optimization: augment all the X's at the beginning of the computation
   -- NOTE: The use case were are optimizing around is when nSamples <= 120
   --       so not much extra space is needed for Xaugemented
   self.Xaugmented = torch.Tensor(self.nSamples, self.nFeatures + 1)
   for i = 1, self.nSamples do
      self.Xaugmented[i] = augment(self.X[i])
   end
   
   -- optimization: precompute Y such that
   -- Y[i][j] == 1 if and only if Y[i] == j
   self.Y = torch.Tensor(self.nSamples, self.nClasses):zero()
   vp(2, 'self.Y:size()', self.Y:size())
   for i = 1, self.nSamples do
      local yi = self.y[i]
      assert(yi >= 0, 
             string.format('y[%d] not at least 1', i, yi))
      assert(yi <= self.nClasses, 
             string.format('y[%d] = %f, exceeds nClasses = %f', i, yi, self.nClasses))
      assert(yi == math.floor(y[i]),
             string.format('y[%d] = %f is not an integer', i, yi))
      vp(2, 'i', i, 'self.y[i]', yi)
      self.Y[i][self.y[i]] = 1
   end

   if verboseLevel > 0 then
      for k, v in pairs(self) do
         vp(1, 'self.' .. k, tostring(v))
      end
   end


end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return flat parameters called theta in the API
-- RETURNS
-- theta : 1D Tensor size (nClasses -1) * (nFeatures + 1)
function LogregOpfunc:initialTheta() 
   local theta = torch.Tensor(self.nUserParameters)
   local stdv = 1 / math.sqrt(self.nFeatures) -- mimic Torch's nn.Linear
   theta:uniform(-stdv, stdv)
   return theta
end

-- return gradient at same parameters as previous call to loss function
-- ARGS
-- lossInfo : table from the loss method
-- RETURNS
-- gradient : 1D Tensor size (nClasses - 1) * (nFeatures + 1)
function LogregOpfunc:gradient(lossInfo)
   assert(type(lossInfo) == 'table')
   return self:_gradientLogLikelihood(lossInfo) + 
          self:_gradientRegularizer(lossInfo) * self.lambda
end

-- return loss and probs at parameters
-- ARGS
-- theta          : 1D Tensor size (nClasses - 1) * (nFeatures + 1)
-- RETURNS
-- loss           : number, regularized negative log likelihood of theta (NLL)
-- lossInfo       : table needed for call to method gradient
--                  the table avoids recomputing values in both the loss and
--                  gradient methods
function LogregOpfunc:loss(theta)
   assert(theta:nDimension() == 1 and theta:size(1) == self.nUserParameters)

   local thetaInfo = self:_structureTheta(theta)
   local scores = self:_scores(thetaInfo)
   local probabilities = self:_probabilities(scores)
   local logLikelihood = self:_logLikelihood(probabilities)
   local regularizer = self:_regularizer(thetaInfo)

   local loss = - logLikelihood + self.lambda * regularizer
   
   local lossInfo = {}
   lossInfo.probabilities = probabilities
   lossInfo.theta = theta
   lossInfo.thetaInfo = thetaInfo

   return loss, lossInfo
end

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------


-- _GRADIENTLOGLIKELIHOOD

function LogregOpfunc:_gradientLogLikelihood(lossInfo, implementation)
   implementation = implementation or 4
   if implementation == 1 then
      return self:_gradientLogLikelihood_implementation_1(lossInfo)
   elseif implementation == 2 then
      return self:_gradientLogLikelihood_implementation_2(lossInfo)
   elseif implementation == 3 then
      return self:_gradientLogLikelihood_implementation_3(lossInfo)
   elseif implementation == 4 then
      return self:_gradientLogLikelihood_implementation_4(lossInfo)
   else
      error('bad implementation value: ' .. tostring(implementation))
   end
end

-- version 1: straight from Murphy b 253
function LogregOpfunc:_gradientLogLikelihood_implementation_1(lossInfo)

   local function gradient_i(i)
      local mu = lossInfo.probabilities[i]
      local y = torch.Tensor(self.nClasses):zero()
      y[self.y[i]] = 1
      local errors = (mu - y) * self.s[i]

      -- view all but last element of errors
      local errorsShort = torch.Tensor(errors:storage(), 1, self.nClasses - 1, 1)

      -- NOTE: must insert the 1 before X[i]
      local result = kroneckerProduct(errorsShort, augment(self.X[i]))
      assert(result:size(1) == self.nUserParameters)

      return result
   end

   local gradient = lossInfo.theta:clone():zero()
   for i = 1, self.nSamples do
      gradient = gradient + gradient_i(i)
   end

   return gradient
end

-- use pre-computed self.Xaugmented
function LogregOpfunc:_gradientLogLikelihood_implementation_2(lossInfo)
   --local vp = makeVp(0, '_gradientLogLikelihood_implementation_2')

   local function gradient_i(i)
      local mu = lossInfo.probabilities[i]
      local y = torch.Tensor(self.nClasses):zero()
      y[self.y[i]] = 1
      local errors = (mu - y) * self.s[i]

      -- view all but last element of errors
      local errorsShort = torch.Tensor(errors:storage(), 1, self.nClasses - 1, 1)

      -- NOTE: must insert the 1 before X[i]
      local result = kroneckerProduct(errorsShort, self.Xaugmented[i])
      assert(result:size(1) == self.nUserParameters)

      return result, errors, errorsShort
   end

   local gradient = lossInfo.theta:clone():zero()
   for i = 1, self.nSamples do
      gradient = gradient + gradient_i(i)
   end

   return gradient
end

-- use pre-computed self.Y
function LogregOpfunc:_gradientLogLikelihood_implementation_3(lossInfo)

   local function gradient_i(i)
      local mu = lossInfo.probabilities[i]
      local errors = (mu - self.Y[i]) * self.s[i]

      -- view all but last element of errors
      local errorsShort = torch.Tensor(errors:storage(), 1, self.nClasses - 1, 1)

      -- NOTE: must insert the 1 before X[i]
      local result = kroneckerProduct(errorsShort, self.Xaugmented[i])
      assert(result:size(1) == self.nUserParameters)

      return result, errors, errorsShort
   end

   local gradient = lossInfo.theta:clone():zero()
   for i = 1, self.nSamples do
      gradient = gradient + gradient_i(i)
   end

   return gradient
end

-- compute errors all at once
function LogregOpfunc:_gradientLogLikelihood_implementation_4(lossInfo)
   local Errors = lossInfo.probabilities - self.Y

   local Gradients = torch.Tensor(self.nSamples, self.nUserParameters)

   for i = 1, self.nSamples do
      local salienceWeightedErrors = Errors[i] * self.s[i]
      local errorsShort = torch.Tensor(salienceWeightedErrors:storage(), 1,  self.nClasses - 1, 1)
      Gradients[i] = kroneckerProduct(errorsShort, self.Xaugmented[i])
   end

   local sumGradients = torch.sum(Gradients, 1)
   local result = torch.Tensor(sumGradients:storage(), 1, self.nUserParameters, 1)
   return result
end



-- _GRADIENTREGULARIZER
function LogregOpfunc:_gradientRegularizer(lossInfo, implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_gradientRegularizer_implementation_1(lossInfo)
   else
      error('bad implementation value: ' .. tostring(implementation))
   end
end

function LogregOpfunc:_gradientRegularizer_implementation_1(lossInfo)
   local weights = lossInfo.thetaInfo.weights
   local regularizerGradient = lossInfo.theta:clone():zero()
   local regularizerIndex = 0
   for c = 1, self.nClasses - 1 do
      regularizerIndex = regularizerIndex + 1
      for d = 1, self.nFeatures do
         regularizerIndex = regularizerIndex + 1
         regularizerGradient[regularizerIndex] = 2 * weights[c][d]
      end
   end
   return regularizerGradient
end


-- determine gradient at i-th observation
-- ref: Murphy, p. 253
function LogregOpfunc:_gradient_i(i, lossInfo, implementation)
   implementation = implementation or 1
   if implementation == 1 then
      return self:_gradient_i_implementation_1(i, lossInfo)
   elseif implementation == 2 then
      return self:_gradient_i_implementation_2(i, lossInfo)
   elseif implementation == 3 then
      return self:_gradient_i_implementation_3(i, lossInfo)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end

function LogregOpfunc:_gradient_i_implementation_1(i, lossInfo)
   local mu = lossInfo.probs[i]
   local y = torch.Tensor(self.nClasses):zero()
   y[self.y[i]] = 1
   local errors = (mu - y) * self.s[i]

   -- view all but last element of errors
   local errorsShort = torch.Tensor(errors:storage(), 1, self.nClasses - 1, 1)

   -- NOTE: must insert the 1 before X[i]
   local gradient_i = kroneckerProduct(errorsShort, augment(self.X[i]))
   assert(gradient_i:size(1) == self.nUserParameters)

   return gradient_i
end
   
-- optimized by
-- . unrolling the kroneckerProduct loop
-- . not shortening the errors vector
-- . not creating the augmented feature vectore [1, X[i]]
-- RESULT: this implementation takes 2.7 times as long as implementation 1
function LogregOpfunc:_gradient_i_implementation_2(i, lossInfo)
   local mu = lossInfo.probs[i]
   local y = torch.Tensor(self.nClasses):zero()
   y[self.y[i]] = 1
   local errors = (mu - y) * self.s[i]
   
   -- compute kroneckerProduct of errors(1:nClasses -1) and [1, self.X[i])
   local gradient_i = torch.Tensor(self.nUserParameters):zero()
   local index = 0
   for c = 1, self.nClasses - 1 do
      index = index + 1
      gradient_i[index] = errors[c]
      for d = 1, self.nFeatures do
         index = index + 1
         gradient_i[index] = errors[c] * self.X[i][d]
      end
   end

   return gradient_i
end

-- optimized by augmenting only once during initialization
-- RESULT: this implementation takes ? times as long as implementation 1
function LogregOpfunc:_gradient_i_implementation_3(i, lossInfo)
   local vp = makeVp(2, 'implementation 3')

   local mu = lossInfo.probs[i]
   local y = torch.Tensor(self.nClasses):zero()
   y[self.y[i]] = 1
   local errors = (mu - y) * self.s[i]
   local errrorsShort = torch.Tensor(errors:storage(), 1, self.nClasses - 1, 1)

   local gradient_i = kroneckerProduct(errorsShort, self.Xaugmented[i])

   return gradient_i
end


-- optimized by vectorizing the errors * 1, X[i] computation in implementation 2
-- RESULT: this implementation takes ? times as long as implementation 1
function LogregOpfunc:_gradient_i_implementation_4(i, lossInfo)
   local vp = makeVp(2, 'implementation 3')

   -- augument the X's all at once
   if self.Xaugmented == nil then
      for i = 1, self.nSamples do
         self.Xaugmentd[i] = augment(self.X[i])
      end
   end
   local mu = lossInfo.probs[i]
   local y = torch.Tensor(self.nClasses):zero()
   y[self.y[i]] = 1
   local errors = (mu - y) * self.s[i]
   
   -- compute kroneckerProduct of errors(1:nClasses -1) and [1, self.X[i])
   local gradient_i = torch.Tensor(self.nUserParameters):zero()
   for c = 1, self.nClasses - 1 do
      local index = self.nFeatures * (c - 1) + 1
      gradient_i[index] = errors[c]

      -- create views so that cmul will work
      local errorVector1 = torch.Tensor{errors[c]}
      errorVector = torch.Tensor(errorVector1:storage(), 1, self.nFeatures, 0)
      vp(2, 'errorVector1', errorVector1, 'errorVector', errorVector)
      gradientVector = torch.Tensor(gradient_i:storage(), index + 1, self.nFeatures, 1)
      vp(2, 'gradientVector pre cmul', gradientVector)
      torch.cmul(gradientVector, errorVector, self.X[i])
      vp(2, 'gradientVector post cmul', gradientVector, 'self.X[i]', self.X[i])
      stop()
   end

   return gradient_i
end


-- _LOGLIKELIHOOD

-- log(likelihood) = sum_i sum_j y_j^i s^i log mu_j^i
-- This implementation has the risk of numeric overflow, because it directly multiplies
-- all the probabilities.
-- ARGS
-- probs         : 2D Tensor of size nFeatures x nClasses
-- RETURNS
-- logLikelihood : number, log of probabiity of the data
--
-- NOTE 1: This implementation has the risk of numeric overflow, because it
-- directly multiplies all the log probabilities and sums them up.
-- However, for the use cases intended, this should not be a problem.
-- OVERFLOW CALCULATIONS: for the problems of interest
--   nSamples <= 120
--   nClasses <= 25
-- avg prob = 1 / (120 * 25) = 1/ 3000
-- log (avg prob) ~= -8
-- l(theta) <= nSamples * nClasses * log(avg prob) = -24000
-- HENCE, risk of overflow is very low for use cases planned
function LogregOpfunc:_logLikelihood(probs)
   local logProbs = torch.log(probs)
   
   local logLikelihood = 0
   for i = 1, self.nSamples do
      logLikelihood = logLikelihood + self.s[i] * logProbs[i][self.y[i]]
   end

   return logLikelihood
end

-- _LOSS1

-- loss1: return loss at given flat parameters
-- ARGS:
-- theta : 1D Tensor size (nClasses - 1) * (nFeatures + 1), flat parameters
-- RETURNS
-- loss  : number, NLL + weighted regularizer

-- _PROBABILITIES

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

-- _REGULARIZER

-- regularizer
function LogregOpfunc:_regularizer(thetaInfo)
   local weights = thetaInfo.weights
   local squaredWeights = torch.cmul(weights, weights)
   local regularizer = torch.sum(squaredWeights)
   return regularizer
end

-- _SCORES

-- compute scores matrix where (scores)_j^i = w_j^T x^i
-- ARGS
-- biases  : 1D Tensor size (nClasses - 1)
-- weights : 2D Tensor size (nClasses - 1) x nFeatures
-- RETURNS
-- scores  : 2D Tensor size nSamples x nClasses
-- NOTE
-- In timing tests. implementation 2 take about 0.012 of the CPU time
-- relative to implementation 1 (it's about 100 times faster)
function LogregOpfunc:_scores(thetaInfo, implementation)
   implementation = implementation or 2
   if implementation == 1 then
      return self:_scores_implementation_1(thetaInfo)
   elseif implementation == 2 then
      return self:_scores_implementation_2(thetaInfo)
   else
      error('bad implemenation value: ' .. tostring(implementation))
   end
end

-- compute scores by explicitly looping over samles and classes
-- ARGS
-- biases  : 1D Tensor size (nClasses - 1)
-- weights : 2D Tensor size (nClasses - 1) x nFeatures
-- RETURNS
-- scores  : 2D Tensor size nSamples x nClasses
function LogregOpfunc:_scores_implementation_1(thetaInfo)
   local biases = thetaInfo.biases
   local weights = thetaInfo.weights

   local scores = torch.Tensor(self.nSamples, self.nClasses)
   
   for i = 1, self.nSamples do
      for c = 1, self.nClasses - 1 do
         scores[i][c] = biases[c] + torch.dot(weights[c], self.X[i])
      end
      scores[i][self.nClasses] = 0
   end

   return scores
end

-- compute scores in one matrix multiplication
--   Scores = XAugmented x W^T
-- ARGS
-- thetaInfo : table containing W size nClasses x (1 + nFeatures)
-- RETURNS
-- scores    : 2D Tensor size nSamples x nClasses
function LogregOpfunc:_scores_implementation_2(thetaInfo)
   return torch.mm(self.Xaugmented, thetaInfo.W:t())
end

-- _STRUCTURETHETA
   
-- parse biases and weights from the flat parameters theta
-- ARGS
-- theta     : 1D Tensor size (nClasses - 1) x (nFeatures + 1)
-- RETURNS
-- thetaInfo : table with these elements
--             biases    : 1D Tensor size (nClasses - 1)
--             weights   : 2D Tensor size (nClasses - 1) x nFeatures
--             W         ; 2D Tensor size nClasses x (nFeatures + 1)
function LogregOpfunc:_structureTheta(theta)
   local nClasses = self.nClasses
   local nFeatures = self.nFeatures

   local biases = 
      torch.Tensor(theta:storage(), 1, 
                   nClasses - 1, nFeatures + 1)

   local weights = 
      torch.Tensor(theta:storage(), 2, 
                   nClasses - 1, nFeatures + 1, 
                   nFeatures, 1)

   local W = torch.Tensor(nClasses, nFeatures + 1):zero()
   for j = 1, self.nClasses - 1 do
      local thetaBiasWeight = 
         torch.Tensor(theta:storage(), 1 + (j - 1) * (nFeatures + 1), nFeatures + 1, 1)
      W[j] = thetaBiasWeight
   end

   return {biases = biases, weights = weights, W = W}
end

  
