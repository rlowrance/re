-- L2RegularizerCriterion.lua
-- This regularizer is the sum of squared weights from some layer

require 'torch'

L2RegularizerCriterion = torch.class('L2RegularizerCriterion')

function L2RegularizerCriterion:__init(layer)
   self.layer = layer
end

function L2RegularizerCriterion:forward(input, target)
   self.output = torch.dot(self.layer.weight, self.layer.weight)
   return regularizer.output
end

function L2RegularizerCriterion:backward(input, target)
   self.gradInput = torch.mul(layer.weight, 2)
   return self.gradInput
end
