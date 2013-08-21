-- test-error.lua

--require 'nn'

-- define class WeightedLinearRegression
do
local WeightedLinearRegression = torch.class('WeightedLinearRegression')

function WeightedLinearRegression:__init()
   self.a = 601
end

function WeightedLinearRegression:estimate(x)

   -- define model
   self.model = 'something'

   print('estimate self', self)
   --WeightedLinearRegression:iterate(23)
   self:iterate(23)
   return 17
end -- method estimate

function WeightedLinearRegression:iterate(y)
   print()
   print('iterate self', self)              -- not same self as in estimate
   print('iterate y', y)
   print('iterate self.model', self.model)  -- value is nil here. Why?
end -- method _iterate
end -- class WeightedLinearRegression

-- use the class

wlr = WeightedLinearRegression(10)
wlr:estimate(17)