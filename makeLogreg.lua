-- makeLogreg.lua
-- logistic regression, with optional 
-- importance weighted samples and L2 regularizer

-- Factored so that various optimization routines can call the functions
-- returned by this function.

require 'augment'
require 'bytesIn'
require 'extract'
require 'hasNaN'
require 'head'
require 'ifelse'
require 'makeSampleIndexer'
require 'makeVp'
require 'maxIndex'
require 'nn'
require 'softmaxes'

local DEBUGGING = true

local function examine2DTensor(name, x)
   local vp, verbose = makeVp(2, 'examine2DTensor')
   local d = verbose > 0
   vp(0, name .. ' takes ' .. bytesIn(x) .. ' bytes')
   assert(x:dim() == 2)
   -- access each element
   for r = 1, x:size(1) do
      for c = 1, x:size(2) do
         local value = x[r][c]
      end
   end
   vp(0, 'each element of ' .. name .. ' was accessed')
end

-- create model for importance weighted multinomial logistic regression
-- ARGS:
-- nDimensions : integer > 0, size of input Tensor
-- nClasses    : integer >= 2, number of classes in target, coded 1, 2, ...
-- name-value  : optional pairs of additional named args
--   'regularizer', 'L2'  use L2 regularizer
--   'lambda', number     coefficient for L2 regularizer
--
-- RETURNS 3 functions and 1 number
-- gradient(parameters, inputs, targets, ['weights', weights]) returns 1D Tensor
-- loss(parameters, inputs, targets, ['weights', weights]) returns avg loss
-- predict(parameters, inputs) returns yhats, probs
-- nParameters : number, size of parameter vector
function makeLogreg(nClasses, nDimensions, ...)
   local vp = makeVp(0, 'makeLogreg')
   vp(1, 'nClasses', nClasses)
   vp(1, 'nDimensions', nDimensions)

   -- validate and parse parameters
   assert(type(nClasses) == 'number' and nClasses >= 2)
   assert(type(nDimensions) == 'number' and nDimensions >= 1)
  
   -- name value pairs and their default value are in nameValues table
   local nameValues = {regularizer =  'none',
                       lambda = 0}
   local varargs = {...}
   local nameValues = {
      regularizer = extract(varargs, 'regularizer', 'none'),
      lambda = extract(varargs, 'lambda', 0)
   }
   vp(1, 'nameValues', nameValues)

   local nParameters = (nClasses - 1) * (nDimensions + 1)

   -- convert flat parameters into 2D Tensor of weights with nClasses-1 rows
   -- create all zeros in last row
   local function structureParameters(parameters)
      local vp = makeVp(0, 'makeLogReg structureParameters')
      vp(1, 'parameters', parameters)
      local theta = torch.Tensor(nClasses, nDimensions + 1):zero()
      local index = 0
      for c = 1, nClasses - 1 do
         index = index + 1
         theta[c][1] = parameters[index] -- bias for class c
         for d = 1, nDimensions  do      -- weights for class c
            index = index + 1
            theta[c][d + 1] = parameters[index]
         end
      end
      vp(1, 'theta', theta)
      return theta
   end


   -- return number, the L2 Regularizer of the structured parameters
   local function regularizerL2(theta)
      local vp = makeVp(0, 'makeLogreg regularizerL2')
      vp(1, 'theta', theta)
      local sum = 0
      for c = 1, nClasses - 1 do
         for d = 1, nDimensions do
            -- don't regularize the biases (theta_{1, c})
            local value = theta[c][d + 1]
            sum = sum + value * value
         end
      end
      vp(1, 'result sum', sum)
      return sum
   end

   -- return 1D Tensor, the L2 gradient of the structured parameters
   local function regularizerL2Gradient(theta)
      local vp = makeVp(0, 'makeLogreg regularizerL2Gradient')
      vp(1, 'theta', theta)
      local g = torch.Tensor(nClasses - 1, nDimensions + 1):zero()
      for c = 1, nClasses - 1 do
         for d = 1, nDimensions do
            -- the biases have already been set to zero
            g[c][d + 1] = 2 * theta[c][d + 1]
         end
      end
      vp(1, 'result structured gradient', g)
      return torch.reshape(g, nParameters)  -- flatten the gradient
   end

   local function regularizerNone(theta)
      return 0
   end

   local function regularizerNoneGradient(theta)
      return torch.Tensor(nParameters):zero()
   end

   local function regularizer(parameters)
      local theta = structureParameters(parameters)
      if nameValues.regularizer == 'none' then
         return regularizerNone(theta)
      elseif nameValues.regularizer == 'L2' then
         return regularizerL2(theta)
      else
         error('bad nameValue.regularizer=' .. nameValue.regularizer)
      end
   end

   local function regularizerGradient(parameters)
      local theta = structureParameters(parameters)
      if nameValues.regularizer == 'none' then
         return regularizerNoneGradient(theta)
      elseif nameValues.regularizer == 'L2' then
         return regularizerL2Gradient(theta)
      else
         error('bad nameValue.regularizer=' .. nameValue.regularizer)
      end
   end

   -- predict target by return 2 values for each input
   -- ARGS
   -- parameters : 1D Tensor of size n
   -- inputs     : 2D Tensor, each row is an observations, or 1D Tensor
   --              if 1D, converted to a 2D Tensor with 1 row
   -- RETURNS 2 values
   -- mle        : number, most likely class
   -- probs      : 2D Tensor of probabilities for each input
   local function predict(parameters, inputs)
      local vp, verbose = makeVp(1, 'makeLogreg predict')
      local d = verbose > 0
      if DEBUGGING then
         vp(0, 'entering')
         --examine2DTensor('inputs', inputs)
      end
      collectgarbage()
      if d then
         vp(1, 'parameters', parameters)
         vp(1, 'head(inputs)', head(inputs))
         vp(1, 'inputs:size()', inputs:size())
         vp(1, 'memory used in bytes', 1024 * collectgarbage('count'))
      end

      -- validate args
      assert(type(parameters) == 'userdata' and
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters not 1D Tensor of size ' .. nParameters)
      if hasNaN(parameters) then
         vp(0, 'parameters', parameters)
         error('parameters contains NaN value')
      end

      -- convert 1D Tensor to 2D Tensor with 1 row
      if type(inputs) == 'userdata' and inputs:dim() == 1 then
         local newInputs = torch.Tensor(1, inputs:size(1))
         newInputs[1] = inputs
         return predict(parameters, newInputs)
      end

      assert(type(inputs) == 'userdata' and
             inputs:dim() == 2,
             'inputs is not 2D Tensor')

      
      local theta = structureParameters(parameters)
      -- prediction for inputs[i]
      -- RETURNS
      -- mle   : number, the best class for input[i]
      -- probs : 1D Tensor, prob[c] == prob(input[i] is in class c]
      local function predict1(i)
         local vp, verbose = makeVp(0, 'model predict 1')
         local d = verbose > 0
         if d then
            vp(1, 'i', i)
            vp(1, 'inputs[i]', inputs[i])
            --vp(1, 'theta', theta)
         end

         -- unormalized probabilities for each class
         local scores = torch.Tensor(nClasses)
         local augmented = augment(inputs[i])
         for c = 1, nClasses do
            scores[c] =  torch.dot(theta[c], augmented)
         end
         if d then vp(2, 'scores', scores) end

         -- probabilites and max likelihood estimate
         local probs = softmaxes(scores)
         local mle = maxIndex(probs)

         if d then
            vp(1, 'mle', mle)
            vp(1, 'probs', probs)
         end
         return mle, probs
      end     

      -- allocate results variables
      local nInputs = inputs:size(1)
      local resultMles = torch.Tensor(nInputs)
      local resultProbs = torch.Tensor(nInputs, nClasses)
      
      -- fill results variables
      for i = 1, nInputs do
         --if DEBUGGING and i % 10000 == 0 then vp(0, 'i', i) end
         if DEBUGGING and i % 10000 == 0 then
            vp(0, 'i', i)
            vp(0, 'memory used in bytes', 1024 * collectgarbage('count'))
         end
         local mle, probs = predict1(i)
         
         collectgarbage()  -- clean up

         resultMles[i] = mle
         resultProbs[i] = probs
      end
      
      if d then
         vp(1, 'head(resultMles)', head(resultMles))
         vp(1, 'head(resultProbs)', head(resultProbs))
      end
      if DEBUGGING then
         vp(0, 'existing')
      end
      return resultMles, resultProbs
   end
   
   -- return weighted gradient + derivate of any regularizer
   -- ARGS
   -- parameters : 1D Tensor
   -- inputs     : 2D Tensor size m x n
   -- targets    : 2D Tensor size m x 1 (column vector)
   -- weights    : optional 2D Tensor size m x 1
   local function gradient(parameters, inputs, targets, ...)
      local vp, verbose = makeVp(0, 'model gradient')
      local d = verbose > 0
      if d then
         vp(1, 'parameters', parameters)
         vp(1, 'inputs', inputs)
         vp(1, 'targets', targets)
      end

      -- validate arguments
      assert(type(parameters) == 'userdata'and
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters not 1D Tensor of size ' .. nParameters)
      assert(type(inputs) == 'userdata' and
             inputs:dim() == 2,
             'inputs not 2D Tensor')
      local nInputs = inputs:size(1)
      assert(type(targets) == 'userdata' and
             targets:dim() == 2 and
             targets:size(1) == nInputs,
             'targets not 2D Tensor of size ' .. nInputs .. ' x 1')

      -- grab weights if supplied
      -- default weights is all ones
      local varargs = {...}
      local weights = extract(varargs, 
                              'weights', 
                              torch.Tensor(nInputs,1):fill(1))

      assert(type(weights) == 'userdata' and
             weights:dim() == 2 and
             weights:size(1) == nInputs,
             'weights not 2D Tensor of size ' .. nInputs .. ' x 1')
      if d then vp(1, 'weights', weights) end

      local mles, probs = predict(parameters, inputs)
      if d then vp(2, 'probs', probs) end

      -- return weighted gradient at sample i 
      -- ref Murphy p 253 equation 8.39
      local function gradient1(i)
         local vp = makeVp(0, 'gradient1')
         local d = verbose > 0
         if d then vp(1, 'i', i) end

         local g = torch.Tensor(nParameters)
         local index = 0
         for c = 1, nClasses - 1 do
            local error = probs[i][c] - ifelse(c == targets[i], 1, 0)
            if d then vp(2, 'error for c=' .. 'c', error) end
            local x = augment(inputs[i])
            for d = 1, nDimensions + 1 do
               index = index + 1
               g[index] = error * x[d] * weights[i]
            end
         end
         if d then vp(1, 'g', g) end
         return g
      end


      -- gradient = sum_i gradient[i] + lambda * regularizerGradient
      local gradientValue = torch.Tensor(nParameters):zero()
      for i = 1, nInputs do
         gradientValue = gradientValue + gradient1(i)
      end
      if d then vp(1, 'gradient without regularizer', gradientValue) end

      gradientValue = 
         gradientValue + regularizerGradient(parameters) * nameValues.lambda
      if d then vp(1, 'regularized gradient', gradientValue) end
      return gradientValue
   end -- gradient

   -- average loss over the samples
   -- loss(theta) = - loglikelihood(theta)
   -- two ways to compute that should be the same:
   -- per Murphy
   -- logLikelihood = formula p.251 formula 8.35
   -- per Andrew Ng, class notes for CS 229, notes 1, p 20
   -- loglikelihood = \sum_i log(\prod_c pr(y_i = c)^{1{y_i = c}}
   -- the second is much shorter and more intuitive
   local function loss(parameters, inputs, targets, ...)
      local vp, verbose = makeVp(2, 'model loss')
      local d = verbose > 0
      if DEBUGGING then
         local k = collectgarbage("count")
         vp(0, 'memory used in Kbytes before gc', k) 
         collectgarbage()
         local k = collectgarbage("count")
         vp(0, 'memory used in Kbytes after gc', k) 
      end
      if d then 
         vp(1, 'parameters', parameters)
         if DEBUGGING then
            vp(1, 'torch.typename(inputs)', torch.typename(input))
            vp(1, 'inputs size is', inputs:size())
            vp(1, 'inputs bytes', bytesIn(inputs))
            vp(1, 'targets bytes', bytesIn(targets))
         end
         if not DEBUGGING then  -- don't print if debugging
            vp(1, 'inputs', inputs)   -- torch-qlua: not enough memory
            vp(1, 'targets', targets)
         end
      end

      -- validate arguments
      if hasNaN(parameters) then
         vp(0, 'parameters', parameters)
         error('parameters has NaN value')
      end

      assert(type(parameters) == 'userdata' and
             parameters:dim() == 1 and
             parameters:size(1) == nParameters,
             'parameters not 1D Tensor of size ' .. nParameters)

      assert(type(inputs) == 'userdata' and
             inputs:dim() == 2 and
             inputs:size(2) == nDimensions,
             'inputs not 2D Tensor of row size ' .. nDimensions)
      local nInputs = inputs:size(1)

      assert(type(targets) == 'userdata' and
             targets:dim() == 1 and
             targets:size(1) == nInputs,
             'targets not 1D Tensor of size ' .. nInputs)


      -- pick up varargs
      local varargs = {...}
      vp(1, 'varargs', varargs)

      -- weights is the importance of each input, default is 1 
      local weights = extract(varargs, 'weights', torch.Tensor(nInputs):fill(1))

      assert(type(weights) == 'userdata' and
             weights:dim() == 1 and
             weights:size(1) == nInputs,
             'weights not 1D Tensor of size ' .. nInputs)

      -- return log likelihood for all inputs and targets
      local function andrewNg()
         local vp, verbose = makeVp(0, 'andrewNg log likelihood')
         local d = verbose > 0
         -- determine probabilities
         local _, probs = predict(parameters, inputs)
         if d then vp(2, 'A Ng probs', probs) end
         
         local sum = 0
         for i = 1, nInputs do
            -- DOES BELOW WORK ONLY IF targets[i] in {0, 1}?
            sum = sum + weights[i] * math.log(probs[i][targets[i]])
         end
         vp(1, 'log likelihood', sum)
         return sum
      end --andrewNg()
         
      -- return log likelihood for all inputs and targets
      -- NOTE: This code is not used in this implementation
      local function kevinMurphy()
         -- structure the flattened parameter vector
         -- set w_C = 0
         local theta = structureParameters(parameters)
         
         -- importance-weighted log likelihood for sample i
         -- ref: Murphy p 253, formula 8.35
         local function weightedLogLikelihood(i)
            local vp, verbose = makeVp(2, 'model weightedLogLikelihood(i)')
            local d = verbose > 0
            if d then vp(1, 'i', i) end
            
            -- prepend 1 to the input and use text's notation
            local x_i = augment(inputs[i])
            local y_i = targets[i]
            
            -- sum over the classes
            -- firstSum = sum_c 1(y_i == c) *  w^T_c * x_i
            -- secondSum = sum_c exp(w^T_c x_i)
            local firstSum = 0
            local secondSum = 0
            for c = 1, nClasses do
               local y_ic = ifelse(y_i == c, 1, 0)
               firstSum = firstSum + y_ic * torch.dot(theta[c], x_i)
               secondSum = secondSum + math.exp(torch.dot(theta[c], x_i))
            end
            if d then 
               vp(2, 'firstSum', firstSum)
               vp(2, 'secondSum', secondSum)
            end
            
            local result = weights[i] * (firstSum - math.log(secondSum))
            if d then vp(1, 'weighted logLikelihood[' .. i .. ']', result) end
            return result
         end
         
         -- determine importance-weight log likelihood across the samples
         local sum = 0
         for i = 1, nInputs do
            sum = sum + weightedLogLikelihood(i)
         end
         if d then vp(2, 'log likelihood', sum) end
         return sum
      end -- kevinMurphy()

      local unRegularizedLoss = - andrewNg()
      
      -- regularize
      local result = 
         unRegularizedLoss + nameValues.lambda * regularizer(parameters)
      if d then vp(1, 'result', result) end
      return result
   end -- loss()


   -- return 3 functions and 1 number
   vp(1, 'nParameters', nParameters)
   return gradient, loss, predict, nParameters
end
