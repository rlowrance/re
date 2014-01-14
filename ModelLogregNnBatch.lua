-- LogregWweighedNnBatch.lua
-- concrete subclass of LogregWeighted, use batch approach with nn package

if false then
   -- API overview
   model = LogregWeightedNnBatch(X, y, s, nClasses, lambda)
   optimalTheta, fitInfo = model:fit(fittingOptions) 
   probs, classes = model:predict(newX2D, theta)       -- returns 1D Tensor of predicted classes
end

require 'keyWithMinimumValue'
require 'LogregOpfuncNnBatch'
require 'LogregWeighted'
require 'makeVp'
require 'printAllVariables'
require 'printTableVariable'

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local LogregWeightedNnBatch, parent = torch.class('LogregWeightedNnBatch', 'LogregWeighted')

function LogregWeightedNnBatch:__init(X, y, s, nClasses, lambda)
   parent.__init(self, X, y, s, nClasses, lambda)
   self.opfunc = LogregOpfuncNnBatch(X, y, s, nClasses, lambda)
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
-- RETURNS: nothing, mutates self
function LogregWeightedNnBatch:runFit(fittingOptions)
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
function LogregWeightedNnBatch:runPredict(newX, theta)
   printAllVariables()
   local probs = self.opfunc:predict(newX, theta)

   local nSamples = newX:size(1)
   local predictions = torch.Tensor(nSamples)
   for sampleIndex = 1, nSamples do
      predictions[sampleIndex] = argmax(probs[sampleIndex])
   end

   return probs,  predictions
end

-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

function LogregWeightedNnBatch:_lossAfterNSteps(stepSize, startingTheta, nSteps)
   local nextTheta = startingTheta
   local loss = nil
   for stepNumber = 1, nSteps do
      -- ISSUE: the computes the first loss (at startingTheta) over and over
      nextTheta, loss = self:_step(stepSize, nextTheta)
   end

   return nextTheta, loss
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
function LogregWeightedNnBatch:_adjustStepSizeAndStep(fittingOptions, currentStepSize, theta)
   local vp = makeVp(2, '_adjustStepSizeAndStep')
   vp(1, 'currentStepSize', currentStepSize)
   local possibleNextStepSizes = fittingOptions.nextStepSizes(currentStepSize)
   vp(2, 'possibleNextStepSizes', possibleNextStepSizes)
   local losses = {}
   local nextThetas = {}
   local nSteps = fittingOptions.nSteps
   for i, stepSize in ipairs(possibleNextStepSizes) do
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
-- hasConverged: boolean
-- howConverged: optional string, if hasConverged == true; reason for convergence
-- result : false or string explaining why the iterations have converged
function LogregWeightedNnBatch:_converged(fittingOptions, 
                                          nEpochs, 
                                          nextTheta, previousTheta, 
                                          nextLoss, previousLoss)
   local maxEpochs = fittingOptions.maxEpochs
   if maxEpochs ~= nil and
      nEpochs >= maxEpochs then
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

   return false
end

-- ARGS
-- fittingOptions : table with these fields
--                  .nEpochsBeforeAdjustingStepSize : number
--                  .maxEpochs : number
--                  .toleranceLoss : number
--                  .toleranceTheta : number
-- RETURNS:
-- fitInfo : table with these fields
--           .convergedReason         : string
--           .nEpochsUntilConvergence : number
--           .optimalTheta            : 1D Tensor
-- SIDE EFFECTS: set self.fitInfo
function LogregWeightedNnBatch:_fitBottouEpoch(fittingOptions)
   local vp = makeVp(2, '_fitBottouEpoch')
   assert(fittingOptions.initialStepSize ~= nil, 'missing fittingOptions.initialStepSize')
   assert(fittingOptions.initialStepSize > 0, 'fittingOptions.initialStepSize not positive')

   -- initialize loop
   local previousTheta = self.opfunc:initialTheta()
   local stepSize = fittingOptions.initialStepSize
   local previousLoss = nil
   local nEpochs = 0

   repeat -- until convergence
      vp(2, 'nEpochs', nEpochs, 'stepSize', stepSize)
      if self:_timeToAdjustStepSize(nEpochs, fittingOptions) then
         -- adjust stepsize and take a step with the adjusted size
         vp(2, 'adjusting step size and stepping')
         stepSize, nextTheta, nextLoss = self:_adjustStepSizeAndStep(fittingOptions, stepSize, previousTheta)
         print('TODO: update nEpochs, accounting for the search')
      else
         -- take a step with the current stepsize
         vp(2, 'stepping with current step size')
         nextTheta, nextLoss = self:_step(stepSize, previousTheta)
      end
      
      nEpochs = nEpochs + 1  -- move this update to the _step() method

      local hasConverged, convergedReason = self:_converged(fittingOptions, 
                                                            nEpochs, 
                                                            nextTheta, previousTheta, 
                                                            nextLoss, previousLoss)
      if hasConverged then
         local fitInfo = {
            convergedReason = convergedReason,
            nEpochsUntilConvergence = nEpochs,
            optimalTheta = nextTheta
         }
         self.fitInfo = fitInfo
         vp(1, 'fitInfo', fitInfo)
         return fitInfo
      end
      
      prevLoss = nextLoss
      prevTheta = nextTheta
   until true
end

-- take a step in the direction of the gradient implied by theta
-- RETURNS
-- nextTheta : 1D Tensor, theta after the step
-- loss      : number, loss at the theta before the step
function LogregWeightedNnBatch:_step(stepSize, theta)
   local vp = makeVp(0, '_step')
   vp(1, 'stepSize', stepSize)
   local loss, lossInfo = self.opfunc:loss(theta)
   local gradient = self.opfunc:gradient(lossInfo)
   vp(2, 'theta', theta)
   local temp = gradient * stepSize
   local nextTheta = theta + gradient * stepSize
   return nextTheta, loss
end

-- determine if the step size should be adjusted
-- ARGS
-- nEpochs : number of epochs already completed, in [0, infinity)
-- fittingOptions : table containing field nEpochsBeforeAdjustingStepSize
-- RETURNS
-- adjustP : boolean, true if nEpochs >= nEpochsBeforeAdjustingStepSize
function LogregWeightedNnBatch:_timeToAdjustStepSize(nEpochs, fittingOptions)
   return (nEpochs % fittingOptions.nEpochsBeforeAdjustingStepSize) == 0
end
