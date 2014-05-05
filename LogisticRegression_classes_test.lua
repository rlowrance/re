-- LogisticRegression_classes_test.luya
-- unit test

require 'nn'
require 'LogisticRegression_classes'


local nSamples = 5
local nClasses = 3
local logprob = torch.rand(nSamples, nClasses)
local target = torch.Tensor{1,2,3,1,2,}
local salience = torch.Tensor{0, .1, .9, .5, .25}

-- return finite difference gradient of loss at point0 using stepsize eps
local function fdGradient(point0, eps, loss)

   local function addDelta(M, i, j, amount)
      local result = M:clone()
      result[i][j] = result[i][j] + amount
      return result
   end

   local fdGradient = point0:clone():zero()
   for i = 1, point0:size(1) do
      for c = 1, point0:size(2) do
         local lossPlus = loss(addDelta(point0, i, c, eps))
         local lossMinus = loss(addDelta(point0, i, c, -eps))
         fdGradient[i][c] = (lossPlus - lossMinus) / (2 * eps)
      end
   end
   return fdGradient
end

local function matrixApproxEqual(A, B, tolerance, printComparisons)
   local allWithinTolerance = true
   for i = 1, A:size(1) do
      for j = 1, A:size(2) do
         local delta = A[i][j] - B[i][j]
         if printComparisons then
            print(i, j, A[i][j], B[i][j], delta)
         end
         allWithinTolerance = allWithinTolerance and (math.abs(delta) < tolerance)
      end
   end
   return allWithinTolerance
end

-- test ClassNLLCriterion

-- return true iff gradient of NLL Criterion is approx correct
local function checkGradientNLLCriterion(eps, tolerance, printComparisons)
   local criterion = nn.ClassNLLCriterion()

   local function loss(logprob)
      criterion:updateOutput(logprob, target)
      return criterion.output
   end

   local function gradient(logprob)
      --print('logprob') print(logprob) print('target') print(target)
      criterion:updateGradInput(logprob, target)
      return criterion.gradInput
   end

   local point0 = torch.rand(nSamples, nClasses)
   local grad = gradient(point0)
   local fdGrad = fdGradient(point0, eps, loss)
   local ok = matrixApproxEqual(grad, fdGrad, tolerance, printComparisons)
   return ok
end

-- test class LogisticRegressionCriterion

-- return true iff gradient of Logistic Regression Criterion is approx correct
local function checkGradientLogisticRegressionCriterion(eps, tolerance, printComparisons)
   local criterion = LogisticRegressionCriterion()

   local myTarget = {y = target, s = salience}

   local function loss(logprob)
      criterion:updateOutput(logprob, myTarget)
      return criterion.output
   end

   local function gradient(logprob)
      criterion:updateGradInput(logprob, myTarget)
      return criterion.gradInput
   end

   local point0 = torch.rand(nSamples, nClasses)
   local grad = gradient(point0)
   local fdGrad = fdGradient(point0, eps, loss)
   local ok = matrixApproxEqual(grad, fdGrad, tolerance, printComparisons)
   return ok
end

local printComparisons = false
assert(checkGradientNLLCriterion(1e-6, 1e-6, printComparisons))
assert(checkGradientLogisticRegressionCriterion(1e-6, 1e-6, printComparisons))
print('ok')
