-- ModelLogisticRegression_test.lua
-- unit test

require 'makeVp'
require 'ModelLogisticRegression'

torch.manualSeed(123)  

local verbose = 2
local vp = makeVp(2, 'tester')

-- construction
local nDimensions = 2
local nClasses = 3
local model = ModelLogisticRegression(nDimensions, nClasses)
if verbose >= 2 then model:print('model') end

-- predict (using :forward)
local input = torch.Tensor{1, 2}
local prediction = model:forward(input)
vp(2, 'prediction', prediction)
stop()


-- parameters
vp(2, 'parameters and gradParameters', model:parameters())
stop()


-- forward
input = torch.Tensor{1,2}
prediction = model:forward(input)
vp(2, 'prediction', prediction)

gradOutput = torch.Tensor{1,1}
gradInput = model:backward(input, gradOutput)
vp(2, 'gradInput', gradInput)

stop()

