-- ObjectivefunctionLogreg_test.lua
-- unit test

require 'ObjectivefunctionLogreg'

local nSamples = 100
local nFeatures = 15
local nClasses = 14
local L2 = .001
local X = torch.Tensor(nSamples, nFeatures)
local y = torch.Tensor(nSamples)
local s = torch.Tensor(nSamples)
local of = ObjectivefunctionLogreg(X, y, s, nClasses, L2)

-- can't do anything, because class is abstract

print('ok ObjectiveFunctionLogreg')

