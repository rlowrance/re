-- makeModelILLogReg.lua
-- Q: Should not the input include a kernel function and the distances?

error('This module does not pass its unit test')
 
require 'makeSampleIndexer'
require 'makeVp'
require 'nn'

-- create model for importance weighted local linear regression
-- ARGS:
-- inputs            : 2D Tensor
-- targets           : 1D Tensor
-- importances       : 1D Tensor
-- queryIndex        : number, 
--                     if >0, index of the query in inputs, targets, importances
-- regularizerLambda : number
--                     coefficient of L2 regularizer
-- kmPerYear         : number
--                     kilometers per year of elapsed time
-- k                 : integer
--                     number of houses to consider as neighbors
-- RETURNS 4 values (so at to be usable by both optim.sgd and optim_vsgdsfd)
-- eval(parameters) returning for a random sample s
--   f(parameters, s)                    -- prediction (1D Tensor of log probs)
--   dLoss_dParameters(parameters, s)    -- derivative
--   NOTE: these results are what is needed for Koray's optim functions
--
-- gradients(parameters, batchId) returning for random sample s
--   {dLoss_dParameters(parameters, s)}  -- derivative
--   NOTE: as needed by optim_vsgdfd
--
-- predict(parameters, input) returning for sample input
--   logProbs                            -- 1D Tensor of log probabilities
--
-- nParameters : integer > 0, number of parameters
function makeModelILLogReg(inputs,
                           targets,
                           importances,
                           queryIndex,
                           regularizerLambda,
                           kmPerYear,
                           k)
   -- define verbose print function
   local vp = makeVp(2, 'makeModelILLogReg')
   vp(1, 'inputs', inputs)
   vp(1, 'targets', targets)
   vp(1, 'importances', importances)
   vp(1, 'queryIndex', queryIndex)
   vp(1, 'regularizerLambda', regularizerLambda)
   vp(1, 'kmPerYear', kmPerYear)
   vp(1, 'k', k)

   -- validate args
   assert(type(inputs) == 'userdata' and
          inputs:dim() == 2,
          'inputs is not 2D Tensor')
   local nInputs = inputs:size(1)
   local nDimensions = inputs:size(2)

   assert(type(targets) == 'userdata' and
          targets:dim() == 1 and
          targets:size(1) == nInputs,
          'targets not 1D Tensor with size same as number rows in inputs')
   local nClasses = 0  -- number of targets is the max value of targets
   for i = 1, nInputs do
      local target = targets[i]
      assert(target >= 1 and math.floor(target) == target,
             'target[' .. i .. '] not positive integer')
      if target > nClasses then
         nClasses = target
      end
   end

   assert(type(importances) == 'userdata' and
          importances:dim() == 1 and
          importances:size(1) == nInputs,
          'importancesnot 1D Tensor with size same as number rows in inputs')
   for i = 1, nInputs do
      assert(importances[i] >= 0,
             'importance[' .. i .. '] is negative')
   end

   assert(type(queryIndex) == 'number' and
          math.floor(queryIndex) == queryIndex and
          0 <= queryIndex and
          queryIndex <= nInputs,
          'queryIndex not integer in [0, number of target classes]')

   assert(type(regularizerLambda) == 'number' and
          regularizerLambda >= 0,
          'regularizerLambda coefficient not a non-negative number')

   assert(type(kmPerYear) == 'number' and
          kmPerYear >= 0,
          'kmPerYear not a non-negative number')

   assert(type(k) == 'number' and
          k >= 1 and
          math.floor(k) == k,
          'k not a postive integer')
   assert(k <= nInputs, 
          'k exceeds number of training samples')

   -- each class has a bias parameter and nInputs parameters
   -- the last class doesn't have parameters
   local nParameters = (nClasses - 1) * (nDimensions + 1)
   vp(1, 'nInputs', nInputs)
   vp(1, 'nDimensions', nDimensions)
   vp(1, 'nClasses', nClasses)
   vp(1, 'nParameters', nParameters)

   -- select a sample that is not the query point
   -- return input, target, importance
   local sampleIndexer = makeSampleIndexer(nInputs)
   function nextSample()
      local nextIndex = sampleIndexer()
      if nextIndex == queryIndex then
         nextIndex = sampleIndexer()
         assert(nextIndex ~= queryIndex)
      end
      return inputs[nextIndex], targets[nextIndex], importances[nextIndex]
   end

   -- return vector of normalized probabilities that input is in each class
   -- RETURN
   -- result[c] == probability that target == c given the parameters and input
   --              for c = 1, ..., nTargets
   local function predict(parameters, input)
      -- validate parameters
      local vp = makeVp(2, 'model predict')
      vp(1, 'parameters', parameters)
      vp(1, 'input', input)
      assert(type(parameters) == 'userdata' and 
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters is not 1D Tensor of length ' .. nParameters)
      assert(type(input) == 'userdata' and
             input:dim() == 1 and
             input:size(1) == nDimensions,
             'input is not 1D Tensor of length ' .. nDimensions)

      -- determine unormalized probabilities for each class
      local parameterIndex = 0
      local uProb = torch.Tensor(nClasses)
      for c = 1, nClasses - 1 do
         parameterIndex = parameterIndex + 1
         local sum = parameters[parameterIndex]  -- bias term
         for d = 1, nDimensions do               -- weight terms
            parameterIndex = parameterIndex + 1
            sum= sum + parameters[parameterIndex] * input[d]
         end
         uProb[c] = math.exp(sum)
      end
      uProb[nClasses] = 1
      vp(2, 'uProb', uProb)

      -- normalization constant
      local z = torch.sum(uProb)
      vp(2, 'z', z)

      -- the prediction is a vector of normalized probabilities
      local prediction = uProb / z
      vp(1, 'probabilities', prediction)
      return prediction
   end

   -- determine loss at input if predicting target with given importance
   -- loss(parameters) = - ll(parameters) where
   --   ll(parameters) is the log likelihood of the parameters given the sample
   -- ref: Murphy, p. 253, definition of f(W)
   -- RETURNS
   -- loss : number, the loss using the args
   -- prediction : 1D Tensor, the predictions using args
   local function loss(parameters, input, target, importance)
      local vp = makeVp(2, 'model loss')
      vp(1, 'parameters', parameter)
      vp(1, 'input', input)
      vp(1, 'target', target)
      vp(1, 'importance', importance)

      -- validate arguments
      assert(type(parameters) == 'userdata' and
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters not 1D Tensor of size ' .. nParameters)
      assert(type(input) == 'userdata' and
             input:dim(1) == 1 and
             input:size(1) == nDimensions,
             'input not 1D Tensor of size ' .. nDimensions)
      assert(type(target) == 'number' and
             1 <= target and
             target <= nClasses,
             'target not valid class number, not in [1,' .. nClasses)
      assert(type(importance) == 'number' and
             importance >= 0,
             'importance not non-negative number')

      local prediction = predict(parameters, input)
      vp(2, 'prediction', prediction)
      local logLikelihood = math.log(prediction[target])
      
      local sumParametersSquared = torch.sum(torch.cmul(parameters, parameters))
      vp(2, 'sumParametersSquared', sumParametersSquared)
      local regularizer = sumParametersSquared * regularizerLambda
      vp(2, 'logLikelihood', logLikelihood)
      vp(2, 'importance', importance)
      vp(2, 'regularizer', regularizer)
      local result =  - logLikelihood * importance + regularizer
      vp(1, 'loss', result)
      return result, prediction
   end

   -- see Murphy, p. 253, formula 8.39
   -- TODO: add in importance and regularizer
   local function gradient(parameters, prediction, input, target, importance)
      local vp = makeVp(2, 'model gradient')
      vp(1, 'parameters', parameters)
      vp(1, 'prediction', prediction)
      vp(1, 'input', input)
      vp(1, 'target', target)
      vp(1, 'importance', importance)

      -- validate args
      assert(type(parameters) == 'userdata' and
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters not 1D Tensor of size ' .. nParameters)
      print(prediction)
      assert(type(prediction) == 'userdata' and
             prediction:dim() == 1 and
             prediction:size(1) == nClasses,
             'prediction not a 1D Tensor of probabilites')
      assert(type(input) == 'userdata' and
             input:dim(1) == 1 and
             input:size(1) == nDimensions,
             'input not 1D Tensor of size ' .. nDimensions)
      assert(type(target) == 'number' and
             1 <= target and
             target <= nClasses,
             'target not valid class number, not in [1,' .. nClasses)
      assert(type(importance) == 'number' and
             importance >= 0,
             'importance not non-negative number')

      local result = torch.Tensor(nParameters)

      local resultIndex = 0
      for c = 1, nClasses -1 do
         vp(2, 'c', c)

         -- set indicator y_c = 1(y == c)
         local y = 0
         if target == c then
            y = 1
         end

         -- set bias term for which x_0 == 1
         resultIndex = resultIndex + 1
         result[resultIndex] = (prediction[c] - y)

         -- set other terms
         for i = 1, nDimensions do
            resultIndex = resultIndex + 1
            vp(2, 'resultIndex', resultIndex)
            result[resultIndex] = (prediction[c] - y) * input[i]
         end
      end
      vp(2, 'gradient before importance and regularizer', result)
      result = result * importance
      result = torch.add(result, parameters * 2)
      vp(1, 'gradient after importance and regularizer', result)
      return result
   end

   -- return loss and derivative
   local function lossDerivative(parameters, input, target, importance)
      local f = loss(parameters, input, target, importance)
      local derivative = 
         gradient(parameters, prediction, input, target, importance)
      return f, derivative
   end

   -- return results required by optim.sgd of its opfunc, namely
   -- f(parameters) : value of loss function at a randomly-selected
   --                 training sample
   -- dLoss_dParameters(parameters) : derivative of loss function at parameters
   --                                 and the same randomly-selected training
   --                                 sample
   local function eval(parameters)
      local input, target, importance = nextSample()
      local prediction = predict(parameters, input)
      return lossDerivative(parameters, input, target, importance)
   end

   -- return results required by optim_vsgdf function, namely
   -- ARGS:
   -- parameters : 1D Tensor of parameters
   -- batchID    : integer > 0, index of set of samples to use
   -- RETURNS:
   -- loss : number, loss at parameters
   -- seq  : sequence of 1D Tensors, each a gradient
   local lastBatchId = 0
   local lastLoss = nil
   local lastDerivate = nil
   local lastInput, lastTarget, lastImportance
   local function gradients(parameters, batchId)
      if batchId == lastBatchId then
         return lastLoss, {lastDerivate}
      end
      local input, target, importance = nextSample()
      lastLoss, lastDerivative = 
         lossDerivate(parameters, input, target, importance)
      return lastLoss, {lastDerivative}
   end

   -- last 2 returned values are not in API
   -- they are for the unit test and debugging
   return eval, gradients, predict, nParameters, loss, gradient
end
      