-- ModelLinearL2Loss.lua
-- predict with WX
-- loss is L2 loss without a regularizer

-- API overview
if false then
   m = ModelLinearL2Loss(nInputs) -- inputs:size(1) == nInputs

   scalar = m:predict(inputs)     -- predict using current weights

   -- return values in same order that optim wants them (fx, dfdx)
   loss, dWeights, prediction = m:ldp(inputs, target) 

   -- access weights
   tensor = m:getWeights()
   m:setWeights(tensor)
end

torch.class('ModelLinearL2Loss')

function ModelLinearL2Loss:__init(nInputs)
   assert(type(nInputs) == 'number')
   self.nInputs = nInputs
   self.weights = torch.randn(nInputs + 1)  -- N(0,1)
end

function ModelLinearL2Loss:predict(inputs)
   assert(inputs:nDimension() == 1)

   local verbose = 0
   local vp = makeVp(verbose)

   vp(1, 'inputs', inputs)
   local prediction = self.weights[1]  -- bias
   for i = 1, self.nInputs do
      prediction = prediction + self.weights[i + 1] * inputs[i]
   end
   vp(1, 'prediction', prediction)
   return prediction
end

function ModelLinearL2Loss:ldp(inputs, target)
   assert(inputs:nDimension() == 1)
   assert(type(target) == 'number')
   local prediction = self:predict(inputs)
   local diff = prediction - target
   local loss = diff * diff
   local dWeights = self.weights * (2 * loss)
   return loss, dWeights, prediction
end

function ModelLinearL2Loss:getWeights()
   return self.weights  -- first weight is bias
end

function ModelLinearL2Loss:setWeights(weights)
   assert(weights:nDimension() == 1)
   assert(weights:size(1) == self.nInputs + 1)  -- allow for bias
   self.weights = weights
end
          