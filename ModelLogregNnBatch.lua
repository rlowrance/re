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

-- ARGS:
-- fittingOptions : table, fields depend on fittingOptions.method
--                  .method : string, must be 'bottouEpoch' for now
--                  .nEpochsBeforeAdjustingStepSize : number
--                  .maxEpochs : number
--                  .toleranceLoss : number
--                  .toleranceTheta : number
-- RETURNS:
-- optimalTheta : 1D Tensor of optimal parameters
-- fitInfo      : table describing the convergence
function ModelLogregNnBatch:runrunFit(fittingOptions)
   assert(type(fittingOptions) == 'table', 'table of fitting options not supplied')
   if fittingOptions.method == 'bottouEpoch' then
      return self:_fitBottouEpoch(fittingOptions)
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
   local vp = makeVp(2, 'runrunPredict')
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
      nextTheta, lossBeforeStep = self:_step(stepSize, nextTheta)
   end

   local lossAfterSteps = self.opfunc:loss(nextTheta)
   return nextTheta, lossAfterSteps
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
-- nextLoss        : number
function ModelLogregNnBatch:_adjustStepSizeAndStep(fittingOptions, currentStepSize, theta)
   local vp = makeVp(0, '_adjustStepSizeAndStep')
   vp(1, 'currentStepSize', currentStepSize)
   local possibleNextStepSizes = fittingOptions.nextStepSizes(currentStepSize)
   vp(2, 'possibleNextStepSizes', possibleNextStepSizes)
   local nSteps = fittingOptions.nEpochsToAdjustStepSize
   vp(2, 'nSteps', nSteps)

   -- take nSteps using each possible step size
   local losses = {}
   local nextThetas = {}
   for _, stepSize in ipairs(possibleNextStepSizes) do
      local nextTheta, loss = self:_lossAfterNSteps(stepSize, theta, nSteps)
      losses[stepSize] = loss
      nextThetas[stepSize] = nextTheta
      vp(2, 'stepSize', stepSize, 'loss', loss)
   end

   local bestStepSize = keyWithMinimumValue(losses)
   vp(1, 'bestStepSize', bestStepSize)
   return bestStepSize, nextThetas[bestStepSize], losses[bestStepSize]
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
   if (maxEpochs ~= nil) and (nEpochsCompleted >= maxEpochs) then
      return true, 'maxEpochs'
   end

   local toleranceLoss = fittingOptions.toleranceLoss
   if (previousLoss ~= nil) and (math.abs(nextLoss - previousLoss) < toleranceLoss) then
      return true, 'toleranceLoss'
   end

   local toleranceTheta = fittingOptions.toleranceTheta
   if (previousTheta ~= nil) and (torch.norm(nextTheta - previousTheta) < toleranceTheta) then
      return true, 'toleranceTheta'
   end

   vp(1, 'did not converge')
   return false, 'did not converge'
end

-- ARGS
-- fittingOptions : table with these fields
--                  .initialStepSize                : number > 0
--                  .nEpochsBeforeAdjustingStepSize : integer > 0
--                  .nEpochsToAdjustStepSize        : integer > 0
--                  .maxEpochs                      : integer > 0
--                  .toleranceLoss                  : number > 0
--                  .toleranceTheta                 : number > 0
--                  NOTE: only one of the last 3 options must be supplied
--                  .printLoss                      : boolean
-- RETURNS:
-- optimalTheta  : 1D Tensor
-- fitInfo       : table with these fields
--                 .convergedReason         : string
--                 .finalLoss               : number
--                 .nEpochsUntilConvergence : number
--
--                 .optimalTheta            : 1D Tensor
-- SIDE EFFECTS: set self.fitInfo
function ModelLogregNnBatch:_fitBottouEpoch(fittingOptions)
   local vp = makeVp(0, '_fitBottouEpoch')
   self:_validateFittingOptions(fittingOptions)

   -- initialize loop
   local printLoss = fittingOptions.printLoss
   local previousLoss = nil
   local previousTheta = self.opfunc:initialTheta()
   local stepSize = fittingOptions.initialStepSize  -- some folks call this variable eta
   local nEpochsCompleted = 0

   repeat -- until convergence
      vp(2, 'nEpochsCompleted', nEpochsCompleted, 'stepSize', stepSize)
      if self:_timeToAdjustStepSize(nEpochsCompleted, fittingOptions) then
         -- adjust stepsize and take a step with the adjusted size
         vp(2, 'adjusting step size and stepping')
         stepSize, nextTheta, nextLoss = self:_adjustStepSizeAndStep(fittingOptions, stepSize, previousTheta)
         nEpochsCompleted = nEpochsCompleted + fittingOptions.nEpochsToAdjustStepSize
      else
         -- take a step with the current stepsize
         vp(2, 'stepping with current step size')
         nextTheta, nextLoss = self:_step(stepSize, previousTheta)
         nEpochsCompleted = nEpochsCompleted + 1
      end

      vp(2, 'nEpochsCompleted', nEpochsCompleted)
      vp(2, 'nextLoss', nextLoss, 'previousLoss', previousLoss)
      if printLoss then
         print(string.format('ModelLogregNnBatch:fit nEpochsCompleted %d stepSize %f nextLoss %f',
                             nEpochsCompleted, stepSize, nextLoss))
      end
      

      local hasConverged, convergedReason, relevantLimit = self:_converged(fittingOptions, 
                                                                           nEpochsCompleted, 
                                                                           nextTheta, previousTheta, 
                                                                           nextLoss, previousLoss)
      vp(2, 'hasConverged', hasConverged, 'convergedReason', convergedReason)

      if hasConverged then
         local fitInfo = {
            convergedReason = convergedReason,
            finalLoss = nextLoss,
            nEpochsUntilConvergence = nEpochsCompleted,
            optimalTheta = nextTheta
         }
         self.fitInfo = fitInfo
         return fitInfo
      end
      
      previousLoss = nextLoss
      previousTheta = nextTheta
   until false
end

-- take a step in the direction of the gradient implied by theta
-- RETURNS
-- nextTheta : 1D Tensor, theta after the step
-- loss      : number, loss at the theta before the step
function ModelLogregNnBatch:_step(stepSize, theta)
   local vp = makeVp(0, '_step')
   vp(1, 'stepSize', stepSize, 'theta', theta)
   local loss = self.opfunc:loss(theta)
   local gradient = self.opfunc:gradient(theta)
   local nextTheta = theta + gradient * stepSize
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
function ModelLogregNnBatch:_validateFittingOptions(fittingOptions)
   validateAttributes(fittingOptions.initialStepSize, 'number', 'positive')
   validateAttributes(fittingOptions.nEpochsBeforeAdjustingStepSize, 'number', 'integer', 'positive')
   validateAttributes(fittingOptions.nEpochsToAdjustStepSize, 'number', 'integer', 'positive')

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
