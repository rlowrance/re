-- WeightedLinearRegression-test.lua
-- unit test of class WeightedLinearRegression

-- from torch


-- from Roy
require 'Distance'
require 'Kernel'
require 'WeightedLinearRegression'


myTests = {}

tester = torch.Tester()

-- generate data
-- redo the example in Hastie
--   The Elements of Statistical Learning
--   2001
--   pp. 168 - 172
function generateXsYs()
   local noiseMean = 0
   local noiseStd = 1/3
   local numSamples = 100

   local function f(x)
      local error = torch.normal(noiseMean, noiseStd)
      return math.sin(4 * x) + error 
   end

   local xs = {}
   local ys = {}
   for i=1,numSamples do
      local x = torch.uniform(0,1)
      local y = torch.Tensor(1):fill(f(x))
      xs[#xs + 1] = torch.Tensor(1):fill(x)
      ys[#ys + 1] = y
   end
   
   return xs, ys
end

-- TODO: fix
-- test accuracy vs. known results, return fraction correct
-- count as correct if within 10%
function testEstimates(name, lr, inputs, targets)
   local countCorrect = 0
   for i,input in ipairs(inputs) do
      local estimate = (lr:estimate(input))[1]
      local expected = targets[i][1]
      local ratio = estimate / expected
      print('testEstimate', estimate, expected, ratio)
      if 0.90 <= ratio and ratio <= 1.10 then 
         countCorrect = countCorrect + 1 
      end
   end
   local fractionCorrect = countCorrect / #inputs
   print('fraction correct', name, fractionCorrect)
   return fractionCorrect
end

-- return kernel-weighted distances from query point to all others
function getWeights(query, xs)
   local lambda = 0.2  -- as per hastie
   local weights = {}
   for i,x in ipairs(xs) do
      local weight = Kernel.epanechnikov(query, x, lambda, Distance.euclidean)
      weights[#weights + 1] = weight
   end
   return weights
end

function runTest()
   print('runTest started')
   local xs, ys = generateXsYs()

   local numDimensions = 1
   local wlr = WeightedLinearRegression(xs, ys, numDimensions)

   -- estimate each query point
   estimates = {}
   opt = {sgd = {epochs = 10, batchSize = 1, params = {}},
          lbfgs = {epochs = 10, batchSize = #xs, params = {}}
   }

   for i=1,#xs do
      local query = xs[i]
      local weights = getWeights(query, xs)
      local estimate = wlr:estimate(query, weights, opt)
      estimates[#estimates + 1] = estimate
      print('runTest', i, estimate[1], ys[i][1])
   end

   -- measure errors
   print('runTest measure error')
   local sumSquaredErrors = 0
   for i=1,#xs do
      local actual = xs[i][1]
      local estimate = estimates[i]
      print('test', actual, estimate)
      local error = actual - estimate
      sumSquaredErrors = sumSquaredErrors + error * error
      print('test', i, actual, estimate)
   end

   local rmse =  math.sqrt(sumSquareErrors / #xs)
   print('rmse', rmse)
   return rmse
end

--------------------------------------------------------------------------------
-- define test cases
--------------------------------------------------------------------------------

--[[
function myTests.testHastie()

   -- CLEMENT: Does CG accept a batch size of 1?
   local rmse = runTest()
   tester.assertle(rmse, 0, 'impossible')
end
--]]

require 'WLR'

function asArrayOfTensors(...)
   local args = {...}
   local result = {}
   for k,v in ipairs(args) do
      result[#result + 1] = torch.Tensor(1):fill(v)
   end
   return result
end

-- 3 point model
function myTests.testRoy()
   print()
   local xs = asArrayOfTensors(0,.5,1)
   local ys = asArrayOfTensors(-.92,-.51,.05) --1 + x + noise
   print('xs', xs)
   print('ys', ys)
   local sumSquaredErrors = 0
   for i=1,3 do
      local lambda = 0.6
      local model = WLR(xs, ys, xs[i], 
                        Kernel.epanechnikov,
                        Distance.euclidean,
                        lambda)
      local estimate = model:estimate()
      local error = ys[i][1] - estimate[1]
      print('testRoy', i, xs[i][1], ys[1][1], estimate[1])
      sumSquaredErrors = sumSquaredErrors + error * error
   end
   local rmse = math.sqrt(sumSquaredErrors / 3)
   print('rmse', rmse)
   tester:assertlt(rmse, 0, 'impossible-adjust later')
end


--------------------------------------------------------------------------------
-- run test cases
-------------------------------------------------------------------------------

tester:add(myTests)
tester:run()
