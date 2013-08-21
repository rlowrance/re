-- makeLogreg_test.lua
-- see lab book 4/28/2013 for hand calculations

require 'assertEq'
require 'checkGradient'
require 'makeLogreg'
require 'makeVp'


torch.manualSeed(123456)

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- find extra printout
if false then
   local vp = makeVp(2, 'find extra printout')
   local gradient, loss, predict, nParameters = makeLogreg(2, 3)
   local inputs = torch.rand(10, 3)
   local targets = torch.Tensor{1,2,1,2,1,2,1,2,1,2}
   local params = torch.rand(nParameters)
   vp(1, 'targets', targets)
   local mle, probs = predict(params, inputs)
end

-- create model and run unit tests
local function check(weights, lambda, regularizer, 
                     testParameters,
                     testNClasses, testNDimensions,
                     testInputs, testTargets, testWeights,
                     expectedYHats1, expectedProbs1, expectedGradient, 
                     expectedLoss)
   local vp = makeVp(0, 'check')
   vp(1, 'weights', weights,
         'lambda', lambda,
         'regularizer', regularizer,
         'testParameters', testParameters,
         'testNClasses', testNClasses,
         'testNDimensions', testNDimensions,
         'testInputs', testInputs,
         'testTargets', testTargets,
         'testWeights', testWeights,
         'expectedYHats1', expectedYHats1,
         'expectedProbs1', expectedProbs1,
         'expectedGradient', expectedGradient,
         'expectedLoss', expectedLoss
     )
   
   -- construct model
   local gradient, loss, predict, nParameters
   if lambda == nil and regularizer == nil then
      gradient, loss, predict, nParameters = 
         makeLogreg(testNClasses, testNDimensions)
   else
      gradient, loss, predict, nParameters = 
         makeLogreg(testNClasses, testNDimensions, 
                    'lambda', lambda, 
                    'regularizer', regularizer)
   end

   -- test nParameters
   assert(nParameters == 2 * 3)

   -- test predict
   local yHats, probs = predict(testParameters, testInputs)
   if expectedYHats ~= nil then
      assertEq(yHats[1], expectedYHats1, 0)
   end
   if expectedProbs1 ~= nil then
      assertEq(probs[1], expectedProbs1, 0.001)
   end

   -- test loss
   local avgLoss
   if testWeights == nil then
      avgLoss = loss(testParameters, testInputs, testTargets)
   else
      avgLoss = 
         loss(testParameters, testInputs, testTargets, 'weights', testWeights)
   end
   if expectedLoss ~= nil then
      assertEq(avgLoss, expectedLoss, .001)
   end

   -- test gradient
   local gradientValue 
   if testWeights == nil then
      gradientValue = gradient(testParameters, testInputs, testTargets)
   else
      gradientValue = gradient(testParameters, testInputs, testTargets,
                               'weights', testWeights)
   end
   if expectedGradient ~= nil then
      assertEq(gradientValue, expectedGradient, .001)
   end

   -- check gradient vs. finite differences TODO: write me
   local function checkGradientDriver(parameters)
      local vp = makeVp(0, 'checkGradientDriver')
      vp(1, 'parameters', parameters)

      -- loss at the parameters
      local function f(parameters)
         if testWeights == nil then
            return loss(parameters, testInputs, testTargets)
         else
            return loss(parameters, testInputs, testTargets, 
                        'weights', testWeights)
         end
      end

      local g 
      if testWeights == nil then
         g = gradient(parameters, testInputs, testTargets)
      else
         g = gradient(parameters, testInputs, testTargets,
                      'weight', testWeights)
      end
      local d, dh = checkGradient(f, parameters, 1e-6, g, 0)
      vp(2, 'g', g)
      vp(2, 'dh', dh)
      vp(2, 'd', d)
      assert(d < 1e-3)
   end

   -- test on supplied parameters and some random ones
   checkGradientDriver(testParameters)
   for i = 1, 10 do
      local randomParameters = torch.rand(nParameters)
      checkGradientDriver(randomParameters)
   end
end

local function checkWeightsRegularizer(w, reg)
   local testParameters = torch.Tensor{.1, .2, .3, -.1, -.2, -.3}
   local testInputs = torch.Tensor{{0,0},{0,1},{1,0},{1,1}}
   local testTargets = torch.Tensor{1, 2, 2, 3}
   local testNClasses = 3
   local testNDimensions = 2

   if w == 'no weights' or w == 'weights = 1' then
 
      -- set weights
      local testWeights = nil
      if w == 'weights = 1' then
         testWeights = torch.Tensor{1, 1, 1, 1}
      end

      if reg == 'no reg' or reg == 'L2 lambda 0' then
         -- no weights no regularizer
         local expectedProbs1 = torch.Tensor{0.3672, 0.3006, 0.3322}
         local expectedYHats1 = 1
         local expectedLoss = 5.1967
         local expectedGradients = 
            torch.Tensor{.8163, .9773, 1.0123, -1.0849, -.5975, -.6252}
         local gradient, loss, predict, nParameters =
            check(testWeights, nil, nil,  -- weights, no lambda, no regularizer
                  testParameters, testNClasses, testNDimensions,
                  testInputs, testTargets, testWeights,
                  expectedYHats1, expectedProbs1, expectedGradients,
                  expectedLoss)
      elseif reg == 'L2 lambda .1' then
         local expectedYHats = nil
         local expectedProbs = nil
         local expectedGradients = nil
         local expectedLoss = nil
         local gradient, loss, predict, nParameters =
            check(nil, 0.1, 'L2',  -- no weights, lambda, regularizer
                  testParameters, testNClasses, testNDimensions,
                  testInputs, testTargets, testWeights,
                  expectedYHats, expectedProbs, expectedGradients,
                  expectedLoss)
      else
         error('bad reg')
      end

   elseif w == 'weightsIncreasing' then
      local testWeights = torch.Tensor{1, 2, 4, 8}

      if reg == 'no reg' or reg == 'L2 lambda 0' then
         -- no weights no regularizer
         local expectedYHats = nil
         local expectedProbs = nil
         local expectedGradients = nil
         local expectedLoss = nil
         local gradient, loss, predict, nParameters =
            check(testWeights, nil, nil,  -- weights, no lambda, no regularizer
                  testParameters, testNCLasses, testNDimensions,
                  testInputs, testTargets, testWeights,
                  expectedYHats, expectedProbs, expectedGradients,
                  expectedLoss)
      elseif reg == 'L2 lambda .1' then
         local expectedYHats = nil
         local expectedProbs = nil
         local expectedGradients = nil
         local expectedLoss = nil
         local gradient, loss, predict, nParameters =
            check(nil, 0.1, 'L2',  -- no weights, lambda, regularizer
                  testParameters, testNClasses, testNDimensions,
                  testInputs, testTargets, testWeights,
                  expectedYHats, expectedProbs, expectedGradients,
                  expectedLoss)
      else
         error('bad w')
      end
   end
end

for _, w in ipairs{'no weights', 'weights = 1', 'weights increasing'} do
   for _, reg in ipairs{'no reg', 'L2 lambda 0', 'L2 lambda .1'} do
      checkWeightsRegularizer(w, reg)
   end
end

print('ok makeLogreg')
