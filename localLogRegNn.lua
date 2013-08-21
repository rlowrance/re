-- localLogRegNn.lua

require 'argmax'
require 'assertEq'
require 'checkGradient'
require 'makeNextPermutedIndex'
require 'makeVp'
require 'memoryUsed'
require 'modelLogreg'
require 'nn'
require 'sgdBottouDriver'
require 'Timer'
require 'unique'
require 'validateAttributes'

-- make the model, optimization criterion, and opfunc needed by the optimizer
-- ARGS:
-- lambda         : number, importance of L2 regularizer
-- nextIndex      : function() --> postive integer, index of next sample to use
--                  function() --> {index1, index2, ...} list of sample indices
-- xs             : Tensor size m x n
-- ys             : Tensor size m x 1
-- ws             : Tensor size m x 1
-- nClasses       : number >= 2
-- checkGradientP : boolean
-- RETURNS
-- opfunc    : function(theta) --> loss, gradient for one or more samples at theta
-- predict   : function(theta, input) --> class number
-- thetaSize : number of elements in the flatten parameters in the model
local function makeOpfuncPredictThetasize(lambda, nextIndex, xs, ys, ws, 
                                          nClasses, checkGradientP)
   local vp, verboseLevel = makeVp(0, 'makeModelCriterionOpfunc')
   vp(1, 'lamba', lambda, 'nextIndex', nextIndex,
      'xs size', xs:size(), 'ys:size()', ys:size(), 'ws size', ws:size(),
      'nClasses', nClasses, 'checkGradientP', checkGradientP)

   -- validate args
   validateAttributes(lambda, 'number', '>=', 0)
   validateAttributes(nextIndex, 'function')
   local nObs = xs:size(1)
   local nDimensions = xs:size(2)
   validateAttributes(nObs, 'number', '>', 1)
   validateAttributes(nDimensions, 'number', '>=', 1)
   validateAttributes(xs, 'Tensor', '2D', 'size', {nObs,nDimensions})
   validateAttributes(ys, 'Tensor', '2D', 'size', {nObs,1})
   validateAttributes(ws, 'Tensor', '2D', 'size', {nObs,1})   
   validateAttributes(nClasses, 'number', '>=', 2)
   validateAttributes(checkGradientP, 'boolean')

   if verboseLevel >= 1 then
      -- print number of examples in each class
      local count = {}
      for i = 1, nObs do
         local class = ys[i][1]
         if count[class] then
            count[class] = count[class] + 1
         else
            count[class] = 1
         end
      end
      for k, v in pairs(count) do
         vp(1, string.format('class %d has %d examples', k, v))
      end
   end

   -- define unregularized model and optimization criterion
   local model = nn.Sequential()
   model:add(nn.Linear(nDimensions, nClasses))
   model:add(nn.LogSoftMax())  -- be sure to call the function!
   
   local criterion = nn.ClassNLLCriterion()
   if v then
      vp(2, 'model', model)
      vp(2, 'criterion', criterion)
   end

   -- couple and flatten parameters and gradient
   local modelTheta, modelGradient = model:getParameters()

   -- predict target value
   -- ARGS:
   -- theta      : 1D Tensor of flattened parameters
   -- input      : 1D Tensor, the input vector
   -- RETURNS
   -- prediction : number, the predicted class
   local function predict(theta, input)
      local vp = makeVp(0, 'predict')
      vp(1, 'theta', theta, 'input', input)

      local prevModelTheta = modelTheta
      local prevModelGradient = modelGradient

      if modelTheta ~= theta then
         modelTheta:copy(theta)
      end

      local prediction = model:forward(input)

      modelTheta = prevModelTheta
      modelGradient = prevModelGradient

      vp(1, 
         'prediction', prediction)
      return prediction
   end

   -- return loss and gradient at a specific sample point
   -- ARGS:
   -- theta      : 1D Tensor of flattened parameters
   -- input      : 1D Tensor, the input vector
   -- target     : number, target for the input
   -- importance : number >= 0, importance of the input
   -- RETURNS
   -- loss       : number, loss from the prediction
   -- gradient   : 1D Tensor, gradient at theta, input, importance
   local function lossGradient(theta, input, target, importance)
      local vp = makeVp(0, 'lossGradient')
      vp(1, 'theta', theta, 'input', input, 'target', target, 'importance', importance)

      local prevModelTheta = modelTheta
      local prevModelGradient = modelGradient

      if modelTheta ~= theta then
         modelTheta:copy(theta)
      end

      local prediction = model:forward(input)
      local loss = criterion:forward(prediction, target) * importance
      local gradCriterion = criterion:backward(prediction, target) * importance
      model:zeroGradParameters()
      model:backward(input, gradCriterion)  -- set modelGradient
      
      -- regularize loss
      local weight = model.modules[1].weight
      local lossRegularized = loss + lambda * torch.sum(torch.cmul(weight, weight))

      -- regularize gradient
      local gradientRegularized = modelGradient:clone()
      local index = 0
      for c = 1, nClasses do
         for d = 1, nDimensions do
            index = index + 1
            gradientRegularized[index] = 
               gradientRegularized[index] + 2 * lambda * weight[c][d]
         end
      end

      modelTheta = prevModelTheta
      modelGradient = prevModelGradient

      vp(1, 
         'lossRegularized', lossRegularized, 'gradientRegularized', gradientRegularized)
      return lossRegularized, gradientRegularized
   end


   -- return loss and gradient for flat parameters theta at next sample point
   -- ARGS
   -- theta               : 1D Tensor, flattened parameters
   -- index               : option integer > 0
   --                       if present, use specified sample index
   --                       if not present, use randommly selected sample index
   -- RETURNS
   -- lossRegularized     : number, the loss regularized
   -- gradientRegularized : 1D tensor, the gradient regularized
   local function opfunc(theta, index)
      local vp, verboseLevel, prefix, vpTable = makeVp(0, 'opfunc')
      local v = verboseLevel > 0
      if v then 
         vp(1, 
            'theta', theta,
            'model', model,   -- upvalues are also args
            'criterion', criterion,
            'modelTheta', modelTheta,
            'modelGradient', modelGradient) 
      end

      validateAttributes(theta, 'Tensor', '1D')
      validateAttributes(index, {'number', 'nil'})

      -- determine next sample index
      local nextSampleIndex = index    -- index specified by caller
      if nextSampleIndex == nil then
         nextSampleIndex = nextIndex() -- next randomly-selected index
      end

      -- set next sample
      local input = xs[nextSampleIndex]
      local target = ys[nextSampleIndex][1]
      local importance = ws[nextSampleIndex][1]
      if v then 
         vp(1, 
            'i', i, 
            'input', input, 
            'target', target, 
            'importance', importance)
      end

      local lossRegularized, gradientRegularized = 
         lossGradient(theta, input, target, importance)
                                                                
      if checkGradientP then
         vp(0, 'remove debugging code for checkGradient')
         local function f(theta)
            return lossGradient(theta, input, target, importance)
         end
         local epsilon = 1e-4
         local checkGradientVerbose = true  -- print comparison element by element
         local normDiff, fdGradient = checkGradient(f, 
                                                    theta, 
                                                    epsilon, 
                                                    gradientRegularized,
                                                    checkGradientVerbose)
         vp(0, 'norm of difference', normDiff, 'epsilon', epsilon)
         assert(normDiff < 10 * epsilon) -- this check is very rough
      end -- checkGradient

      vp(1, 
         'lossRegularized', lossRegularized, 'gradientRegularized', gradientRegularized)
      return lossRegularized, gradientRegularized
   end

   local modelSize = modelTheta:size(1)
   vp(1, 'opfunc', opfunc, 'predict', predict, 'modelSize', modelSize)
   return opfunc, predict, modelSize
end


-- fit weighted logistic regression model with an L2 regularizer
-- ARGS:
-- nClasses      : integer >= 2, number of classes
-- xs            : 2D Tensor size m x nDimensions of observations
-- ys            : 2D Tensor size m x 1 of targets
-- ws            : 2D Tensor size m x 1 of importance weights
--                 must sum to 1
--                 examples with importance of zero are not used
-- lambda        : number, L2 regularizer coefficient
-- checkGradient : boolean
-- RETURNS
-- predict   : function(thetaStar, newX) --> class number
-- thetaStar : 1D Tensor of flattened optimal parameters
local function fitModel(nClasses, xs, ys, ws, lambda, checkGradient)
   -- ref: http://torch.cogbits.com/doc/tutorials_supervised/
   local vp, verboseLevel = makeVp(0, 'fitModel')
   local v = verboseLevel > 0
   if v then
      vp(1, 
         'nClasses', nClasses,
         'xs size', xs:size(),
         'ys size', ys:size(),
         'ws size', ws:size(),
         'lambda', lambda,
         'checkGradient', checkGradient)
   end

   -- validate arguments
   validateAttributes(nClasses, 'number', '>=', 2)
   local nObs = xs:size(1)
   local nDimensions = xs:size(2)
   validateAttributes(xs, 'Tensor', '2D', 'size', {nObs,nDimensions})
   validateAttributes(ys, 'Tensor', '2D', 'size', {nObs,1})
   validateAttributes(ws, 'Tensor', '2D', 'size', {nObs,1})   
   validateAttributes(lambda, 'number', '>=', 0)
   validateAttributes(checkGradient, 'boolean')

   assert(math.abs(torch.sum(ws) - 1) < 1e-6,
          'importance weights do not sum to about 1')

   -- functions to run generate sample indices
   local nextPermutedIndex = makeNextPermutedIndex(xs:size(1))

   local opfunc, predict, thetaSize =
      makeOpfuncPredictThetasize(lambda,
                                 nextPermutedIndex,
                                 xs,
                                 ys,
                                 ws,
                                 nClasses,
                                 checkGradient)

   -- use Bottou's SGD via sgdBottouDriver
   local function newEtas(eta)
      return {0.7 * eta, 1.3 * eta}
   end

   local configSgdBottou = 
      {nSamples = nObs,
       nSubsamples = nObs,  -- use all samples when exploring candidate etas
       eta = 1,             -- initial eta
       newEtas = newEtas,
       evalCounter = nObs,  -- evals before checking eta
       printEta = false}  
   local initialTheta = torch.rand(thetaSize)
   local tolX = 0.1
   local tolF = 1e-03
   local maxEpochs = nil
   local thetaStar, avgLoss, state =
      sgdBottouDriver(opfunc,
                      configSgdBottou,
                      nObs,
                      initialTheta,
                      tolX, 
                      tolF,
                      maxEpochs,
                      verbose)
   vp(2, 'thetaStar', thetaStar)   
   vp(2, 'avgLoss', avgLoss)
   vp(2, 'state', state)
   vp(1, 'predict', predict, 'thetaStar', thetaStar)
   return predict, thetaStar
end


-- make a prediction using a local logistic regression model and torch's
-- neural net infrastructure. Do not call modelLogreg!
-- ARGS:
-- xs            : 2D Tensor size m x n, each row an observation
-- ys            : 2D Tensor size m x 1, of classes in {1, 2, ..., nClasses}
-- ws            : 2D Tensor size m x 1, the importance of each xs[i] to newX
-- newX          : 2D Tensor size 1 x n, point of prediction
-- lambda        : number, lambda for L2 regularizer
-- checkGradient : boolean
-- RETURNS
-- prediction : number in {1, ..., nClasses}, predicted class for newX
-- NOTES
-- - This implementation is optimized for the use case in which only a 
--   relatively few examples have non-zero importance.
function localLogRegNn(xs, ys, ws, newX, lambda, checkGradient)
   local vp, verbose = makeVp(0, 'localLogRegNn')
   local d = verbose > 0
   if d then
      vp(1, '\n******************* localLogRegNn')
      vp(1, 
         --'head xs', head(xs),
         --'head ys', head(ys),
         --'head ws', head(ws),
         'xs size', xs:size(),
         'ys size', ys:size(),
         'ws size', ws:size(),
         'newX', newX,
         'lambda', lambda,
         'checkGradient', checkGradient)
   end

   -- validate input
   local nObs = xs:size(1)
   local nDimensions = xs:size(2)
   validateAttributes(xs, 'Tensor', '2D', 'size', {nObs,nDimensions})
   validateAttributes(ys, 'Tensor', '2D', 'size', {nObs,1})
   validateAttributes(ws, 'Tensor', '2D', 'size', {nObs,1})   
   validateAttributes(newX, 'Tensor', '2D', 'size', {1,nDimensions})
   validateAttributes(lambda, 'number', '>=', 0)
   validateAttributes(checkGradient, 'boolean')

   -- remove any examples that have zero importance
   if torch.sum(torch.eq(ws, 0)) > 0 then
      -- optimize for the use case in which only a few examples have
      -- non-zero importance
      local isRetained = torch.ne(ws,0)
      local nRetainedIndices = torch.sum(isRetained)
      local xsNew = torch.Tensor(nRetainedIndices, nDimensions)
      local ysNew = torch.Tensor(nRetainedIndices, 1)
      local wsNew = torch.Tensor(nRetainedIndices, 1)
      local nextNewIndex = 0
      for i = 1, nObs do
         --vp(3, string.format('isRetained[%d]=', i), isRetained[i])
         if isRetained[i][1] == 1 then
            nextNewIndex = nextNewIndex + 1
            vp(3, 'setting i', i, 'nextNewIndex', nextNewIndex)
            vp(3, 'xs[i]', xs[i])
            xsNew[nextNewIndex] = xs[i]
            ysNew[nextNewIndex] = ys[i]
            wsNew[nextNewIndex] = ws[i]
         end
      end
      vp(1, 'examples with some importance')
      vp(1, 'xsNew', xsNew, 'ysNew', ysNew, 'wsNew', wsNew)
      return localLogRegNn(xsNew, ysNew, wsNew, newX, lambda, checkGradient)
   end

   if false then
      -- DEBUG CODE: TURN ME OFF
      vp(0, 'TURN OFF DEBUG CODE: set all weights but one very small')
      local verySmall = 1e-4
      for i = 1, nObs do
         ws[i][1] = verySmall
      end
      ws[9][1] = 1 - 8 * verySmall
   end
      

   -- determine number of classes and check coding of classes
   local maxY = torch.max(ys)
   local minY = torch.min(ys)
   validateAttributes(minY, 'number', '>=', 1)
   validateAttributes(maxY, 'number', '>=', 2, '>=', minY)
   local nClasses = maxY
   -- The subset we see may have less than the max number of codes

   if d then 
      vp(2, 'nObs', nObs, 'nDimensions', nDimensions, 'nClasses', nClasses)
   end

   -- fit the model
   vp(2, 'fitting modelLogReg')
   local timer = Timer()
   local predict, thetaStar = fitModel(nClasses, xs, ys, ws, lambda, checkGradient)
   vp(2, 'model', model)
   vp(1, 'cpu seconds to fit model', timer:cpu())

   -- predict at the query point
   local query = torch.Tensor(newX:size(2))
   for d = 1, newX:size(2) do
      query[d] = newX[1][d]
   end
   vp(2, 'query', query)
   local probs = predict(thetaStar, query)
   vp(2, 'probs', probs)
   local prediction = argmax(probs)
   vp(1, 'prediction', prediction)
   
   if verbose >= 2 then
      -- print details, assuming a few examples
      for i = 1, nObs do  -- print examples
         local s = string.format('%2d: x ', i)
         for d = 1, nDimensions do
            s = s .. string.format('%4.1f ', xs[i][d])
         end
         s = s .. string.format('y %2d ', ys[i][1])
         s = s .. string.format('w %f', ws[i][1])
         vp(0, s)
      end
      -- print query
      local s = ' q: x '
      for d = 1, nDimensions do
         s = s .. string.format('%4.1f ', newX[1][d])
      end
      s = s .. string.format('prediction %2d', prediction)
      vp(0, s)
      --pressEnter()
   end
         
   assert(1 <= prediction)
   assert(prediction <= nClasses)
   return prediction
end

   

   
   
