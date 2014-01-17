-- LogregWweighedNnBatch.lua
-- concrete subclass of ModelLogreg, use batch approach with nn package

if false then
   -- API overview
   model = ModelLogregNnBatch(X, y, s, nClasses, lambda)
   optimalTheta, fitInfo = model:fit(fittingOptions) 
   probs2D, classes1D = model:predict(newX2D, theta)  
end

require 'keyWithMinimumValue'
require 'ModelLogreg'
require 'makeVp'
require 'OpfuncLogregNnBatch'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'vectorToString'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local ModelLogregNnBatch, parent = torch.class('ModelLogregNnBatch', 'ModelLogreg')

function ModelLogregNnBatch:__init(X, y, s, nClasses, lambda)
   local vp = makeVp(0, '__init')
   vp(1, 'parent', parent)
   vp(1, 'X', X, 'y', y, 's', s, 'nClasses', nClasses, 'lambda', lambda)
   parent.__init(self, X, y, s, nClasses, lambda)
   self.opfunc = OpfuncLogregNnBatch(X, y, s, nClasses, lambda)
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
--                  .initialStepSize                : number > 0
--                  .nEpochsBeforeAdjustingStepSize : integer > 0
--                  .nEpochsToAdjustStepSize        : integer > 0
--                  .maxEpochs                      : integer > 0
--                  .method                         : string
--                  .nextStepSizes                  : function(stepSize) --> sequence of step sizes
--                  .toleranceLoss                  : number > 0
--                  .toleranceTheta                 : number > 0
--                  NOTE: only one of the last 3 options must be supplied
--                  .printLoss                      : boolean
-- RETURNS:
-- optimalTheta  : 1D Tensor
-- fitInfo       : table with these fields
--                 .convergedReason         : string
--                 .finalLoss               : number, loss before the last step taken
--                 .nEpochsUntilConvergence : number
--
--                 .optimalTheta            : 1D Tensor
-- RETURNS:
-- optimalTheta : 1D Tensor of optimal parameters
-- fitInfo      : table describing the convergence
-- NOTES; errors if the loss from epoch to epoch every increases
-- This is because NnBatch computes the entire gradient and we know that a step size
-- exists where there is always a reduction in the error.
function ModelLogregNnBatch:runrunFit(fittingOptions)
   assert(type(fittingOptions) == 'table', 'table of fitting options not supplied')
   local method = fittingOptions.method
   if method == 'bottouEpoch' then
      return self:_fitBottouEpoch(fittingOptions)
   elseif method == 'gradientDescent' then
      return self:_fitGradientDescent(fittingOptions)
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
function ModelLogregNnBatch:runrunPredict(newX, theta)
   local vp = makeVp(0, 'runrunPredict')
   assert(newX:nDimension() == 2, 'newX is not a 2D Tensor')
   assert(theta:nDimension() == 1, 'theta is not a 1D Tensor')
   --printAllVariables()

   vp(1, 'self.opfunc', self.opfunc)
   local probs = self.opfunc:predictions(newX, theta)

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
function ModelLogregNnBatch:_lossAfterNSteps(stepSize, startingTheta, nSteps)
   local nextTheta = startingTheta
   local loss = nil
   for stepNumber = 1, nSteps do
      nextTheta, lossBeforeLastStep = self:_step(stepSize, nextTheta)
   end

   local lossAfterSteps = self.opfunc:loss(nextTheta)
   return nextTheta, lossAfterSteps, lossBeforeLastStep
end

-- adjust the step size by testing several choices and return the best
-- "best" means the stepsize that reduces the current loss the most
-- ARGS
-- fittingOptions  : table
-- currentStepSize        : number > 0
-- theta           : 1D Tensor
-- RETURNS
-- bestStepSize    : number
-- nextTheta       : 1D Tensor
-- lossBeforeStep  : number, the loss before the last step taken
function ModelLogregNnBatch:_adjustStepSizeAndStep(fittingOptions, currentStepSize, theta)
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
function ModelLogregNnBatch:_converged(fittingOptions, 
                                       nEpochsCompleted, 
                                       nextTheta, previousTheta, 
                                       nextLoss, previousLoss)
   local vp = makeVp(0, '_converged') 
   vp(2, 'nEpochsComplete', nEpochsCompleted)
   
   local maxEpochs = fittingOptions.maxEpochs
   if maxEpochs ~= nil then
      if nEpochsCompleted >= maxEpochs then
         return true, 'maxEpochs'
      end
   end

   local toleranceLoss = fittingOptions.toleranceLoss
   if toleranceLoss ~= nil then
      if previousLoss ~= nil then 
         if math.abs(nextLoss - previousLoss) < toleranceLoss then
            return true, 'toleranceLoss'
         end
      end
   end

   local toleranceTheta = fittingOptions.toleranceTheta
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
function ModelLogregNnBatch:_fitBottouEpoch(fittingOptions)
   local vp = makeVp(0, '_fitBottouEpoch')
   self:_validateFittingOptionsBottouEpoch(fittingOptions)

   -- initialize loop
   local printLoss = fittingOptions.printLoss
   local previousLoss = nil
   local lossBeforeStep = nil
   local lossIncreasedOnLastStep = false
   local previousTheta = self.opfunc:initialTheta()
   local stepSize = fittingOptions.initialStepSize  -- some folks call this variable eta
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, '----------------- loop restarts')
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      vp(2, 'previousLoss', previousLoss, 'previousTheta', vectorToString(previousTheta))
      vp(2, 'lossIncreasedOnLastStep', tostring(lossIncreasedOnLastStep))
      if self:_timeToAdjustStepSize(nEpochsCompleted, fittingOptions) or 
         lossIncreasedOnLastStep then
         -- adjust stepsize and take a step with the adjusted size
         vp(2, 'adjusting step size and stepping')
         stepSize, nextTheta, lossBeforeStep = 
            self:_adjustStepSizeAndStep(fittingOptions, stepSize, previousTheta)
         nEpochsCompleted = nEpochsCompleted + fittingOptions.nEpochsToAdjustStepSize
      else
         -- take a step with the current stepsize
         vp(2, 'stepping with current step size')
         nextTheta, lossBeforeStep = self:_step(stepSize, previousTheta)
         nEpochsCompleted = nEpochsCompleted + 1
      end

      vp(2, 'lossBeforeStep', lossBeforeStep, 'nextTheta', vectorToString(nextTheta))
      if printLoss then
         print(string.format('ModelLogregNnBatch:_fitBottouEpoch nEpochsCompleted %d stepSize %f lossBeforeStep %f',
                             nEpochsCompleted, stepSize, lossBeforeStep))
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(fittingOptions, 
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
         lossIncreasedOnLastStep = lossBeforeStep > previousLoss
         if lossIncreasedOnLastStep then
            error(string.format('loss increased from %f to %f on epoch %d',
            previousLoss, lossBeforeStep, nEpochsCompleted))
         end
      end
      
      previousLoss = lossBeforeStep
      previousTheta = nextTheta
   until false
end

-- fit using gradient decent with a fixed step size
function ModelLogregNnBatch:_fitGradientDescent(fittingOptions)
   local vp = makeVp(0, '_fitGradientDescent')
   self:_validateFittingOptionsGradientDescent(fittingOptions)

   -- initialize loop
   local printLoss = fittingOptions.printLoss
   local stepSize = fittingOptions.initialStepSize  -- some folks call this variable eta

   local previousLoss = nil
   local previousTheta = self.opfunc:initialTheta()
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, '----------------- loop restarts')
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      vp(2, 'previousLoss', previousLoss, 'previousTheta', vectorToString(previousTheta))
      vp(2, 'lossIncreasedOnLastStep', tostring(lossIncreasedOnLastStep))
      
      local nextTheta, lossBeforeStep = self:_step(stepSize, previousTheta)
      nEpochsCompleted = nEpochsCompleted + 1

      if printLoss then
         print(string.format('ModelLogregNnBatch:_fitGradientDescent nEpochsCompleted %d stepSize %f lossBeforeStep %f',
                             nEpochsCompleted, stepSize, lossBeforeStep))
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(fittingOptions, 
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

-- take a step in the direction of the gradient implied by theta
-- RETURNS
-- nextTheta : 1D Tensor, theta after the step
-- loss      : number, loss at the theta before the step
function ModelLogregNnBatch:_step(stepSize, theta)
   local vp = makeVp(0, '_step')
   vp(1, 'stepSize', stepSize, 'theta', vectorToString(theta))
   local loss = self.opfunc:loss(theta)
   local gradient = self.opfunc:gradient(theta)
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
function ModelLogregNnBatch:_timeToAdjustStepSize(nEpochsCompleted, fittingOptions)
   return (nEpochsCompleted % fittingOptions.nEpochsBeforeAdjustingStepSize) == 0
end

   
-- check types and values of fields we use in the fittingOptions table
function ModelLogregNnBatch:_validateFittingOptionsBottouEpoch(fittingOptions)
   local function present(fieldName)
      assert(fittingOptions[fieldName] ~= nil,
             'fittingOptions missing field ' .. fieldName)
   end

   present('initialStepSize')
   present('nEpochsBeforeAdjustingStepSize')
   present('nEpochsToAdjustStepSize')
   present('nextStepSizes')

   validateAttributes(fittingOptions.initialStepSize, 'number', 'positive')
   validateAttributes(fittingOptions.nEpochsBeforeAdjustingStepSize, 'number', 'integer', 'positive')
   validateAttributes(fittingOptions.nEpochsToAdjustStepSize, 'number', 'integer', 'positive')
   assert(type(fittingOptions.nextStepSizes) == 'function', 
          'fittingOptions.nextStepSizes is not a function')

   if fittingOptions.maxEpochs ~= nil then
      validateAttributes(fittingOptions.maxEpochs, 'number', 'integer', 'positive')
   end

   if fittingOptions.toleranceLoss ~= nil then
      validateAttributes(fittingOptions.toleranceLoss, 'number', 'positive')
   end

   if fittingOptions.toleranceTheta ~= nil then
      validateAttributes(fittingOptions.toleranceTheta, 'number', 'positive')
   end

   assert(fittingOptions.maxEpochs ~= nil or
          fittingOptions.toleranceLoss ~= nil or
          fittingOptions.toleranceTheta ~= nil,
          'at least one convergence options must be specified')
end

-- check types and values of fields we use in the fittingOptions table
function ModelLogregNnBatch:_validateFittingOptionsGradientDescent(fittingOptions)
   local function present(fieldName)
      assert(fittingOptions[fieldName] ~= nil,
             'fittingOptions missing field ' .. fieldName)
   end

   present('initialStepSize')

   validateAttributes(fittingOptions.initialStepSize, 'number', 'positive')

   if fittingOptions.maxEpochs ~= nil then
      validateAttributes(fittingOptions.maxEpochs, 'number', 'integer', 'positive')
   end

   if fittingOptions.toleranceLoss ~= nil then
      validateAttributes(fittingOptions.toleranceLoss, 'number', 'positive')
   end

   if fittingOptions.toleranceTheta ~= nil then
      validateAttributes(fittingOptions.toleranceTheta, 'number', 'positive')
   end

   assert(fittingOptions.maxEpochs ~= nil or
          fittingOptions.toleranceLoss ~= nil or
          fittingOptions.toleranceTheta ~= nil,
          'at least one convergence options must be specified')
end
