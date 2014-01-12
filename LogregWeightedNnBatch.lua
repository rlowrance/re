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

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

local LogregWeightedNnBatch, parent = torch.class('LogregWeightedNnBatch', 'LogregWeighted')

function LogregWeightedNnBatch:__init(X, y, s, nClasses, lambda)
   parent.__init(self, X, y, s, nClasses, lambda)
   self.opfunc = LogregOpfuncNnBatch(X, y, s, nClasses, lambda)
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


-- adjust the step size by testing several choices and return the best
-- "best" means the stepsize that reduces the current loss the most
-- ARGS
-- fittingOptions  : table
-- stepSize        : number > 0
-- theta           : 1D Tensor
-- RETURNS
-- bestStepSize    : number
-- nextTheta       : 1D Tensor
-- nextLoss        : number
function LogregWeightedNnBatch:_adjustStepSizeAndStep(fittingOptions, stepSize, theta)
   local possibleNextStepSizes = fittingOptions.nextStepSizes(currentStepSize)
   local losses = {}
   local thetas = {}
   for i, stepSize in ipairs(possibleNextStepSizes) do
      local loss, theta = self:_loss(stepSize, theta) 
      losses[stepSize] = loss
      thetas[stepSize] = theta
   end
   local bestStepSize = keyWithMinimumValue(loss)
   return bestStepSize, thetas[bestStepSize], losses[bestStepSize]
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
-- RETURNS nil
-- SIDE EFFECTS: set these fields in self
-- .convergedReason         : string
-- .nEpochsUntilConvergence : number
-- .optimalTheta            : 1D Tensor
function LogregWeightedNnBatch:_fitBottouEpoch(fittingOptions)
   assert(fittingOptions.initialStepSize ~= nil, 'missing fittingOptions.initialStepSize')
   assert(fittingOptions.initialStepSize > 0, 'fittingOptions.initialStepSize not positive')

   -- initial loop
   local previousTheta = opfunc:initialTheta()
   local stepSize = fittingOptions.initialStepSize
   local previousLoss = nil
   local nEpochs = 0

   repeat -- until convergence
      if self._timeToAdjustStepSize(nEpochs, fittingOptions) then
         -- adjust stepsize and take a step with the adjusted size
         stepSize, nextTheta, nextLoss = self:_adjustStepSizeAndPages(fittingOptions, stepSize, previousTheta)
      else
         -- take a step with the current stepsize
         nextTheta, nextLoss = self:_step(stepSize, previousTheta)
      end
      
      nEpochs = nEpochs + 1

      local hasConverged, convergedReason = self:_converged(fittingOptions, 
                                                            nEpochs, 
                                                            nextTheta, previousTheta, 
                                                            nextLoss, previousLoss)
      if hasConverged then
         self.convergedReason = convergedReason
         self.nEpochsUntilConvergence = nEpochs
         self.optimalTheta = nextTheta
         return
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
   local loss, lossInfo = self.opfunc:loss(theta)
   local gradient = self.opfunc:gradient(lossInfo)
   local nextTheta = previousTheta + gradient * stepSize
   return nextTheta, loss
end
