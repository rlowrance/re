-- ClassNLLCriterionL2.lua
-- Like ClassNLLCriterion but with an L2 regularizer

local ClassNLLCriterionL2, parent = torch.class('ClassNLLCriterionL2',
                                                'nn.ClassNLLCriterion')

function ClassNLLCriterionL2:__init(lambda)
   parent.__init(self)

   assert(type(lambda) == 'number')
   assert(lambda >= 0)
   self.lambda = lambda
end

function ClassNLLCriterionL2:updateOutput(input, target)
   local output = parent.updateOutput(self, input, target)
   return output * lambda  -- ?? need the weights
end

   