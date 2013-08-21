-- WeightedMSEModelCriterion.lua
-- TODO: write down the formulae

require 'Validations'

-- combination model and criterion for weighted linear regression
-- API
-- wmmc = WeightedMSEModelCriterion(weightFunction, xs, numDimensions)
-- [loss] wmmc:forward(input)
-- [gradInput] wmmc:backward(input, target)
-- [estimate] wmmc:estimate(query)
local WeightedMSEModelCriterion = torch.class('WeightedMSEModelCriterion')

-- initialize instance
-- +weight        : function:: (x1, x2) --> number
--                  the weighted distance between two table elements
-- +xs            : table, each element is an observed input, a 1D Tensor
-- +numDimensions : number, dimensions in each xs element
function WeightedMSEModelCriterion:__init(weight, xs, numDimensions)
   Validations.isFunctionOrTable(weight, 'weight')
   Validations.isTable(xs, 'xs')
   Validations.isTensor1D(xs[1], 'xs[1]')
   Validations.isNumberGt0(numDimensions, 'numDimensions')

   self.weight = weight
   self.xs = xs
   -- the parameters are a and b so that estimate = a + b * input
   self.a = torch.normal(0, 1/math.sqrt(1+numDimensions))
   self.b = torch.Tensor(numDimensions)
   for i = 1, numDimensions do
      self.b[i] = torch.normal(0, 1/math.sqrt(2))
   end
   
   self.lastCumLoss = 0
   self.lastEstimate = 0
end

-- return loss given current parameters for a single input
-- update self.lastEstimate (as if from a call to a model)
-- and    self.lastLoss (as if from a call to a criterion)
function WeightedMSEModelCriterion:forward(input, target)
   Validations.isTensor1D(input, 'input')
   Validations.isTensor1D(target, 'target')
   print('forward input,target', input, target)
   self.lastEstimate = self:estimate(input)
   print('forward lastEstimate', self.lastEstimate)
   local error = target - self.lastEstimate

   -- accumulate loss over all training points
   self.lastLoss = 0
   for _, x in pairs(self.xs) do
      local weightValue = self.weight(input, x)
      local loss = weightValue * torch.dot(error, error)
      print('forward weightValue, loss, x', weightValue, loss, x)
      self.lastLoss = self.lastLoss + loss
   end

   print('forward cum loss', self.lastLoss)
   return self.lastLoss
end

-- return estimate, a 1D Tensor of size 1, given current parameters
-- query is a Tensor with one element
function WeightedMSEModelCriterion:estimate(query)
   Validations.isTensor1D(query, 'query')
   print('estimate a,b,query', self.a, self.b, query)
   self.lastEstimate = torch.Tensor(1):fill(self.a + torch.dot(self.b, query))
   print('estimate result', self.lastEstimate)
   return self.lastEstimate
end

-- return gradient of loss function for input and target
-- remember last gradient computed
function WeightedMSEModelCriterion:backward(input, target)
   Validations.isTensor(input)
   Validations.isTensor(target)
   local cumGradient = 
      torch.Tensor(1 + self.numDimensions):fill(0)  -- accumulator
   for _, x in pairs(xs) do
      local estimate = self:estimate(input)
      local error = target - estimate
      Validations.isTensor1D(error, 'error')
      local constant = weight(input, x) * error[1]
      local gradient = torch.Tensor(self.numDimensions)
      gradient[1] = 1
      for k = 1,#numDimensions do
         gradient[1 + k] = input[k]
      end
      cumGradient = cumGradient + gradient
   end
   return cumGradient
end

      
   