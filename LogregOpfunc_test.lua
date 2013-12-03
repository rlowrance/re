-- LogregOpfunc_test.lua
-- unit test

require 'makeVp'
require 'LogregOpfunc'
require 'Timer'

torch.manualSeed(123)

local vp = makeVp(2, 'tester')

-- unit tests
local nSamples = 5
local nFeatures = 8
local nClasses = 3
local lambda = 0.001

local X = torch.rand(nSamples, nFeatures)

local y = torch.Tensor(nSamples)
local class = 0
for i = 1, nSamples do
   class = class + 1
   if class == nClasses then class = 1 end
   y[i] = class
end

local s = torch.Tensor(nSamples)
s:uniform(0, 1)

local of = LogregOpfunc(X, y, s, nClasses, lambda)
vp(2, 'of', of)

local parameters = of:initialParameters()
vp(2, 'parameters', parameters)
assert(parameters:nElement() == (nClasses - 1) * (nFeatures + 1))

-- change the parametes
for i = 1, parameters:size(1) do
   parameters[i] = i / 10
end

local loss, probs = of:loss(parameters)
vp(2, 'loss', loss, 'probs', probs)

local gradient = of:gradient(parameters, probs)
vp(2, 'gradient', gradient)

-- check gradient

-- timing test
local timer = Timer()
local nIterations = 1000
for i = 1, nIterations do
   local loss, probs = of:loss(parameters)
end
vp(2, 'avg loss cpu', timer:cpu() / nIterations)
stop()
print('ok LogregOpfunc')
