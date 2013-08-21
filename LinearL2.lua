-- LinearL2.lua
-- Linear model with L2 regularizer

local LinearL2, parent = torch.class('LinearL2', 'nn.Module')

function LinearL2:__init(inputSize, outputSize, lambda)
   -- validate args
   assert(type(inputSize) == 'number' and inputSize > 0)
   assert(type(outputSize) == 'number' and outputSize > 0)
   assert(type(lamba) == 'number' and lambda >= 0)

   parent.__init(self)
   self.linear = nn.Linear(inputSize, outputSize)
   self.lambda = lambda
end

function LinearL2:updateOutput(input)
   self.linear:updateOutput(input)
   -- how to regularize the output is not clear
end

function LinearL2:updateGradInput(input, gradOutput)
   parent.updateGradInput(self, input, gradOutput)
   
   self.weight = self.weight + self.weight * (2 * lambda)
end