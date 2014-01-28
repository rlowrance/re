-- ModelLogregNnbatch.lua
-- concrete subclass of ModelLogreg, use batch approach with nn package

if false then
   -- API overview
   model = ModelLogregNnbatch(X, y, s, nClasses, lambda)
   optimalTheta, fitInfo = model:fit(fittingOptions) 
   probs2D, classes1D = model:predict(newX2D, theta)  
end

require 'keyWithMinimumValue'
require 'ModelLogreg'
require 'makeVp'
require 'ObjectivefunctionLogregNnbatch'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'vectorToString'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local ModelLogregNnbatch, parent = torch.class('ModelLogregNnbatch', 'ModelLogreg')

function ModelLogregNnbatch:__init(X, y, s, nClasses, lambda)
   local vp = makeVp(0, '__init')
   vp(1, 'parent', parent)
   vp(1, 'X', X, 'y', y, 's', s, 'nClasses', nClasses, 'lambda', lambda)
   parent.__init(self, X, y, s, nClasses, lambda)
   self.objectivefunction = ObjectivefunctionLogregNnbatch(X, y, s, nClasses, lambda)
   --printTableVariable('self')
end

-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- methods are:
--   bottouEpoch     : step size is adjusted periodically starting at initialStepSize
--   gradientDescent : step size is fixed at initialStepSize
-- ARGS
-- fittingOptions : table with these fields
--                  .method         : string \in {'bottouEpoch', 'gradientDescent', 'lbfgs'}
--                  .convergence    : table with at least one of these fields
--                                    .maxEpochs
--                                    .toleranceLoss
--                                    .toleranceTheta
--                 .printLoss       : boolean, loss is printed at each step if true
--                 .bottouEpoch     : optional table with these fields
--                                    .callBackEndOfEpoch(lossBeforeStep, currentTheta, stepSize) : optional function
--                                    .initialStepSize                : number > 0
--                                    .nEpochsBeforeAdjustingStepSize : integer > 0
--                                    .nEpochsToAdjustStepSize        : integer > 0
--                                    .nextStepSizes                  ; function(currentSize) --> seq of new sizes
--                 .gradientDescent : optional table with these fields
--                                    .stepSize  : number, fixed for all iterations
--                 .lbfgs           : optional table with these fields
--                                    .lineSearch        : a line search function or 
--                                                         'wolf' 
--                                                         or a number (fixed step size)
--                                    .lineSearchOptions : optional table
-- RETURNS:
-- optimalTheta  : 1D Tensor
-- fitInfo       : table with these fields
--                 .convergedReason         : string
--                 .finalLoss               : number, loss before the last step taken
--                 .nEpochsUntilConvergence : number
--                 .optimalTheta            : 1D Tensor
-- RETURNS:
-- optimalTheta : 1D Tensor of optimal parameters
-- fitInfo      : table describing the convergence
function ModelLogregNnbatch:runrunFit(fittingOptions)
   assert(type(fittingOptions) == 'table', 'table of fitting options not supplied')
   local convergence = fittingOptions.convergence
   local printLoss = fittingOptions.printLoss

   self:_validateOptionConvergence(convergence)
   assert(type(printLoss) == 'boolean', 'printLoss not supplied')
   
   local method = fittingOptions.method
   if method == 'bottouEpoch' then
      assert(fittingOptions.bottouEpoch, 'did not supply bottouEpoch field')
      return self:_fitBottouEpoch(convergence, fittingOptions.bottouEpoch, printLoss)

   elseif method == 'gradientDescent' then
      assert(fittingOptions.gradientDescent, 'did not supply gradientDescent field')
      return self:_fitGradientDescent(convergence, fittingOptions.gradientDescent, printLoss)

   elseif method == 'lbfgs' then
      assert(fittingOptions.lbfgs, 'did not supply fittingOptions fields')
      return self:_fitLbfgs(convergence, fittingOptions.lbfgs, printLoss)

   else
      error(string.format('unknown fitting method %s', tostring(fittingOptions.method)))
   end
end

-- ARGS
-- newX          : 2D Tensor
-- theta         : 1D Tensor of flat parameters
-- RETURNS
-- probs         ; 2D Tensor
-- predictions   : 1D Tensor
-- RETURNS
-- predictions : 2D Tensor of probabilities
-- predictInfo : table
--               .mostLikelyClasses : 1D Tensor of integers, the most likely class numbers
function ModelLogregNnbatch:runrunPredict(newX, theta)
   local vp = makeVp(0, 'runrunPredict')
   assert(newX ~= nil, 'newX is nil')
   assert(newX:nDimension() == 2, 'newX is not a 2D Tensor')
   
   assert(theta ~= nil, 'theta is nil')
   assert(theta:nDimension() == 1, 'theta is not a 1D Tensor')

   vp(1, 'self.objectivefunction', self.objectivefunction)
   local probs = self.objectivefunction:predictions(newX, theta)

   local nSamples = newX:size(1)
   local mostLikelyClasses = torch.Tensor(nSamples)
   for sampleIndex = 1, nSamples do
      mostLikelyClasses[sampleIndex] = argmax(probs[sampleIndex])
      vp(2, 'sampleIndex', sampleIndex, 
            'probs[]', probs[sampleIndex], 
            'mostLikelyClasses[]', mostLikelyClasses[sampleIndex])
   end

   vp(1, 'probs', probs, 'mostLikelyClasses', mostLikelyClasses)
   return probs,  {mostLikelyClasses = mostLikelyClasses}
end

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

-- return nextTheta and loss after taking nSteps of specified stepSize
function ModelLogregNnbatch:_lossAfterNSteps(stepSize, startingTheta, nSteps)
   local nextTheta = startingTheta
   local loss = nil
   for stepNumber = 1, nSteps do
      nextTheta, lossBeforeLastStep = self:_step(stepSize, nextTheta)
   end

   local lossAfterSteps = self.objectivefunction:loss(nextTheta)
   return nextTheta, lossAfterSteps, lossBeforeLastStep
end

-- adjust the step size by testing several choices and return the best
-- "best" means the stepsize that reduces the current loss the most
-- ARGS
-- fittingOptions  : table
-- currentStepSize : number > 0
-- theta           : 1D Tensor
-- printLoss       : boolean
-- RETURNS
-- bestStepSize    : number
-- nextTheta       : 1D Tensor
-- lossBeforeStep  : number, the loss before the last step taken
function ModelLogregNnbatch:_adjustStepSizeAndStep(fittingOptions, currentStepSize, theta, printLoss)
   local vp = makeVp(0, '_adjustStepSizeAndStep')
   vp(1, 'currentStepSize', currentStepSize)
   vp(2, 'theta', vectorToString(theta))
   local possibleNextStepSizes = fittingOptions.nextStepSizes(currentStepSize)
   vp(3, 'possibleNextStepSizes', possibleNextStepSizes)
   local nSteps = fittingOptions.nEpochsToAdjustStepSize
   vp(2, 'nSteps', nSteps)

   -- take nSteps using each possible step size
   local lossesAfterSteps = {}
   local lossesBeforeLastStep = {}
   local nextThetas = {}
   for _, stepSize in ipairs(possibleNextStepSizes) do
      local nextTheta, lossAfterSteps, lossBeforeLastStep = self:_lossAfterNSteps(stepSize, theta, nSteps)
      lossesAfterSteps[stepSize] = lossAfterSteps
      lossesBeforeLastStep[stepSize] = lossBeforeLastStep
      nextThetas[stepSize] = nextTheta
      vp(2, 'stepSize', stepSize, 'lossAfterSteps', lossAfterSteps)
      if printLoss then
         print(string.format('stepsize %f leads to loss of %f', stepSize, lossAfterSteps))
      end
   end

   local bestStepSize = keyWithMinimumValue(lossesAfterSteps)
   local nextTheta = nextThetas[bestStepSize]
   local lossBeforeStep = lossesBeforeLastStep[bestStepSize]
   vp(1, 'bestStepSize', bestStepSize)
   vp(1, 'nextTheta', vectorToString(nextTheta))
   vp(1, 'lossBeforeStep', lossBeforeStep)
   return bestStepSize, nextTheta, lossBeforeStep
end

-- determine if we have converged
-- RETURNS
-- hasConverged  : boolean
-- howConverged  : string, if hasConverged == true; reason for convergence
function ModelLogregNnbatch:_converged(convergence, 
                                       nEpochsCompleted, 
                                       nextTheta, previousTheta, 
                                       nextLoss, previousLoss)
   local vp = makeVp(0, '_converged') 
   vp(2, 'nEpochsComplete', nEpochsCompleted)
   
   local maxEpochs = convergence.maxEpochs
   if maxEpochs ~= nil then
      if nEpochsCompleted >= maxEpochs then
         return true, 'maxEpochs'
      end
   end

   local toleranceLoss = convergence.toleranceLoss
   if toleranceLoss ~= nil then
      if previousLoss ~= nil then 
         if math.abs(nextLoss - previousLoss) < toleranceLoss then
            return true, 'toleranceLoss'
         end
      end
   end

   local toleranceTheta = convergence.toleranceTheta
   if toleranceTheta ~= nil then 
      if previousTheta ~= nil then
         if torch.norm(nextTheta - previousTheta) < toleranceTheta then
            return true, 'toleranceTheta'
         end
      end
   end

   vp(1, 'did not converge')
   return false, 'did not converge'
end

-- fit using Bottou's method where the iterants are epochs
function ModelLogregNnbatch:_fitBottouEpoch(convergence, bottouEpoch, printLoss)
   local vp = makeVp(0, '_fitBottouEpoch')
   self:_validateBottouEpochOptions(bottouEpoch)

   -- initialize loop
   local callBackEndOfEpoch = bottouEpoch.callBackEndOfEpoch
   local previousLoss = nil
   local lossBeforeStep = nil
   local lossIncreasedOnLastStep = false
   local previousTheta = self.objectivefunction:initialTheta()
   local stepSize = bottouEpoch.initialStepSize  -- some folks call this variable eta
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, '----------------- loop restarts')
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      vp(2, 'previousLoss', previousLoss, 'previousTheta', vectorToString(previousTheta))
      vp(2, 'lossIncreasedOnLastStep', tostring(lossIncreasedOnLastStep))
      if self:_timeToAdjustStepSize(nEpochsCompleted, bottouEpoch) or 
         lossIncreasedOnLastStep then
         -- adjust stepsize and take a step with the adjusted size
         vp(2, 'adjusting step size and stepping')
         stepSize, nextTheta, lossBeforeStep = 
            self:_adjustStepSizeAndStep(bottouEpoch, stepSize, previousTheta, printLoss)
         nEpochsCompleted = nEpochsCompleted + bottouEpoch.nEpochsToAdjustStepSize
      else
         -- take a step with the current stepsize
         vp(2, 'stepping with current step size')
         nextTheta, lossBeforeStep = self:_step(stepSize, previousTheta)
         nEpochsCompleted = nEpochsCompleted + 1
      end

      vp(2, 'lossBeforeStep', lossBeforeStep, 'nextTheta', vectorToString(nextTheta))
      if printLoss then
         print(string.format('ModelLogregNnbatch:_fitBottouEpoch nEpochsCompleted %d stepSize %f lossBeforeStep %f',
                             nEpochsCompleted, stepSize, lossBeforeStep))
      end
      
      if callBackEndOfEpoch then
         callBackEndOfEpoch(lossBeforeStep, nextTheta, stepSize)
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(convergence, 
                                                                           nEpochsCompleted, 
                                                                           nextTheta, previousTheta, 
                                                                           lossBeforeStep, previousLoss)
      vp(2, 'hasConverged', hasConverged, 'convergedReason', convergedReason)

      if hasConverged then
         local fitInfo = {
            convergedReason = convergedReason,
            finalLoss = lossBeforeStep,
            nEpochsUntilConvergence = nEpochsCompleted,
            optimalTheta = nextTheta
         }
         self.fitInfo = fitInfo
         if printLoss then
            local function p(fieldName)
               print('converged fitInfo.' .. fieldName .. ' = ' .. tostring(fitInfo[fieldName]))
            end
            p('convergedReason')
            p('finalLoss')
            p('nEpochsUntilConvergence')
         end
         return nextTheta, fitInfo
      end
      
      -- error if the loss is increasing
      -- Because we are doing full gradient descent, there is always a small enough stepsize
      -- so that the loss will not increase.
      if previousLoss ~= nil then
         lossIncreasedOnLastStep = lossBeforeStep > previousLoss
         if lossIncreasedOnLastStep and printLoss then
            print(string.format('loss increased from %f to %f on epoch %d',
                                previousLoss, lossBeforeStep, nEpochsCompleted))
         end
      end
      
      previousLoss = lossBeforeStep
      previousTheta = nextTheta
   until false
end

-- fit using gradient decent with a fixed step size
function ModelLogregNnbatch:_fitGradientDescent(convergence, gradientDescent, printLoss)
   local vp = makeVp(0, '_fitGradientDescent')
   assert(gradientDescent)
   self:_validateGradientDescentOptions(gradientDescent)

   -- initialize loop
   local stepSize = gradientDescent.stepSize  -- some folks call this variable eta

   local previousLoss = nil
   local previousTheta = self.objectivefunction:initialTheta()
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, '----------------- loop restarts')
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      vp(2, 'previousLoss', previousLoss, 'previousTheta', vectorToString(previousTheta))
      vp(2, 'lossIncreasedOnLastStep', tostring(lossIncreasedOnLastStep))
      
      local nextTheta, lossBeforeStep = self:_step(stepSize, previousTheta)
      nEpochsCompleted = nEpochsCompleted + 1

      if printLoss then
         print(string.format('ModelLogregNnbatch:_fitGradientDescent nEpochsCompleted %d stepSize %f lossBeforeStep %f',
                             nEpochsCompleted, stepSize, lossBeforeStep))
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(convergence, 
                                                                           nEpochsCompleted, 
                                                                           nextTheta, previousTheta, 
                                                                           lossBeforeStep, previousLoss)
      vp(2, 'hasConverged', hasConverged, 'convergedReason', convergedReason)

      if hasConverged then
         local fitInfo = {
            convergedReason = convergedReason,
            finalLoss = lossBeforeStep,
            nEpochsUntilConvergence = nEpochsCompleted,
            optimalTheta = nextTheta
         }
         self.fitInfo = fitInfo
         return nextTheta, fitInfo
      end
      
      -- error if the loss is increasing
      -- Because we are doing full gradient descent, there is always a small enough stepsize
      -- so that the loss will not increase.
      if previousLoss ~= nil then
         local lossIncreasedOnLastStep = lossBeforeStep > previousLoss
         if lossIncreasedOnLastStep then
            error(string.format('loss increased from %f to %f on epoch %d',
            previousLoss, lossBeforeStep, nEpochsCompleted))
         end
      end
      
      previousLoss = lossBeforeStep
      previousTheta = nextTheta
   until false
end

-- fit using L-BFGS
function ModelLogregNnbatch:_fitLbfgs(convergence, lbfgs, printLoss)
   local vp = makeVp(0, '_fitLbfgs')
   self:_validateLbfgsOptions(lbfgs)

   -- configure optim.lbfgs
   local lineSearch = lbfgs.lineSearch
   local config = {}
   if lineSearch == 'wolf' then
      config.lineSearch = optim.lswolf
   elseif type(lineSearch) == 'number' then
      config.lineSearch = lineSearch
   elseif type(lineSearch) == 'function' then
      config.lineSearch = lineSearch
      config.lineSearchOptions = lbfgs.lineSearchOptions
   else
      error('invalid lbfgs.lineSearch: ' .. tostring(lineSearch))
   end

   local function opfunc(theta)
      return self.objectivefunction:lossGradient(theta)
   end

   local previousLoss = nil
   local previousTheta = self.objectivefunction:initialTheta()
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, '----------------- loop restarts')
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      vp(2, 'previousLoss', previousLoss, 'previousTheta', vectorToString(previousTheta))
      vp(2, 'lossIncreasedOnLastStep', tostring(lossIncreasedOnLastStep))
      
      local nextTheta, fValues = optim.lbfgs(opfunc, previousTheta, config)
      local lossBeforeStep = fValues[#fValues]
      nEpochsCompleted = nEpochsCompleted + 1

      if printLoss then
         print(string.format('ModelLogregNnbatch:_fitLbfgs: nEpochsCompleted %d stepSize %f lossBeforeStep %f',
                             nEpochsCompleted, stepSize, lossBeforeStep))
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(convergence, 
                                                                           nEpochsCompleted, 
                                                                           nextTheta, previousTheta, 
                                                                           lossBeforeStep, previousLoss)
      vp(2, 'hasConverged', hasConverged, 'convergedReason', convergedReason)

      if hasConverged then
         local fitInfo = {
            convergedReason = convergedReason,
            finalLoss = lossBeforeStep,
            nEpochsUntilConvergence = nEpochsCompleted,
            optimalTheta = nextTheta
         }
         self.fitInfo = fitInfo
         return nextTheta, fitInfo
      end
      
      previousLoss = lossBeforeStep
      previousTheta = nextTheta
   until false
end

-- take a step in the direction of the gradient implied by theta
-- RETURNS
-- nextTheta : 1D Tensor, theta after the step
-- loss      : number, loss at the theta before the step
function ModelLogregNnbatch:_step(stepSize, theta)
   local vp = makeVp(0, '_step')
   vp(1, 'stepSize', stepSize, 'theta', vectorToString(theta))
   local loss = self.objectivefunction:loss(theta)
   local gradient = self.objectivefunction:gradient(theta)
   vp(2, 'gradient', vectorToString(gradient))
   local nextTheta = theta - gradient * stepSize
   vp(1, 'loss before step', loss, 'nextTheta', vectorToString(nextTheta))
   return nextTheta, loss
end

-- determine if the step size should be adjusted
-- ARGS
-- nEpochsCompleted : number of epochs already completed, in [0, infinity)
-- fittingOptions : table containing field nEpochsBeforeAdjustingStepSize
-- RETURNS
-- adjustP : boolean, true if nEpochsCompleted >= nEpochsBeforeAdjustingStepSize
function ModelLogregNnbatch:_timeToAdjustStepSize(nEpochsCompleted, fittingOptions)
   return (nEpochsCompleted % fittingOptions.nEpochsBeforeAdjustingStepSize) == 0
end

-- check types and values of fields we use in the fittingOptions table
function ModelLogregNnbatch:_validateBottouEpochOptions(options)
   local function present(fieldName)
      assert(options[fieldName] ~= nil,
             'options missing field ' .. fieldName)
   end

   present('initialStepSize')
   present('nEpochsBeforeAdjustingStepSize')
   present('nEpochsToAdjustStepSize')
   present('nextStepSizes')

   validateAttributes(options.initialStepSize, 'number', 'positive')
   validateAttributes(options.nEpochsBeforeAdjustingStepSize, 'number', 'integer', 'positive')
   validateAttributes(options.nEpochsToAdjustStepSize, 'number', 'integer', 'positive')
   assert(type(options.nextStepSizes) == 'function', 
          'options.nextStepSizes is not a function')

   
   if options.callBackEndOfEpoch ~= nil then
      assert(type(options.callBackEndOfEpoch == 'function',
                  'callBackEndOfEpoch not a function of (lossBeforeStep, nextTheta)'))
   end
end

-- check convergence options
-- NOTE: other convergence criteria are given at search(torch7 logistic regression example)
function ModelLogregNnbatch:_validateOptionConvergence(convergence)
   assert(convergence ~= nil, 'convergence option not supplied')

   if convergence.maxEpochs ~= nil then
      validateAttributes(convergence.maxEpochs, 'number', 'integer', 'positive')
   end

   if convergence.toleranceLoss ~= nil then
      validateAttributes(convergence.toleranceLoss, 'number', 'positive')
   end

   if convergence.toleranceTheta ~= nil then
      validateAttributes(convergence.toleranceTheta, 'number', 'positive')
   end

   assert(convergence.maxEpochs ~= nil or
          convergence.toleranceLoss ~= nil or
          convergence.toleranceTheta ~= nil,
          'at least one convergence options must be specified')

   return
end
   
-- check types and values of fields we use in the gradientDescent options table
function ModelLogregNnbatch:_validateGradientDescentOptions(options)
   local function present(fieldName)
      assert(options[fieldName] ~= nil,
             'options missing field ' .. fieldName)
   end

   present('stepSize')
   validateAttributes(options.stepSize, 'number', 'positive')

end

-- check types and values of fields in lbfgs options table
function ModelLogregNnbatch:_validateLbfgsOptions(options)
   local function present(fieldName)
      assert(options[fieldName] ~= nil,
             'options missing field ' .. fieldName)
   end

   present('lineSearch')
   local value = options.lineSearch
   local t = type(value)
   if value == 'wolf' or
      t == 'number' or
      t == 'function' then
      return
   else
   error( 'lineSearch not "wolf" or a number of a function')
   end
end

