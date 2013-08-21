-- NnwEstimatorLlr-test.lua
-- unit test

require 'all'

test = {}
tester = Tester()

function test.one()
   -- this is a very weak tests, it checks for completion
   -- figuring out a problem to solve by hand seems complicated
   local v = makeVerbose(false, 'test.one')
   local nObs = 3
   local nDims = 2
   local xs = torch.Tensor(nObs, nDims)
   local ys = torch.Tensor(nObs)
   for i = 1, nObs do
      ys[i] = 100 * i
      for d = 1, nDims do
         xs[i][d] = 10 * i + d
      end
   end

   local llr = NnwEstimatorLlr(xs, ys, 'epanechnikov quadratic')
   
   local query = torch.Tensor(nDims)
   query[1] = 23
   query[2] = 31
   query = xs[2]  -- its \hat y must be about 200

   local params = {}
   params.k = 3
   params.regularizer = 0.01
   local ok, estimate = llr:estimate(query, params)
   v('estimate', estimate)
   tester:assert(ok)
   tester:assertgt(estimate, 0)
end -- test.one

function test.two()
   -- attempt to recover known generator
   -- y = a x1 + b x2 + c
   local v = makeVerbose(false, 'test.two')
   local a = 2
   local b = 3
   local c = 4
   local nObs = 10
   local nDims = 2
   local xs = torch.Tensor(nObs, nDims)
   local ys = torch.Tensor(nObs)
   -- model is y = a x1 + b x2 + c + error
   torch.manualSeed(27)
   for i = 1, nObs do
      for j = 1, nDims do
         xs[i][j] = i * 10 + j
         xs[i][j] = i * 10 + j 
      end
      ys[i] = a * xs[i][1] + b * xs[i][2] + c + torch.normal(0,1)
   end
   v('a,b,c', a, b, c)
   v('xs', xs)
   v('ys', ys)

   -- re-estimate every observation with k nearest neighbors
   llr = NnwEstimatorLlr(xs, ys, 'epanechnikov quadratic')
   ks = {3, 5}
   ks = {5}
   for _, k in ipairs(ks) do
      for i = 1, nObs do
         local actual = ys[i]
         local params = {}
         params.k = k
         params.regularizer = 1e-5 -- leads to singularity for k=3, i=3
         params.regularizer = 1e-6 -- singular for k=5, i=4
         params.regularizer = 1e-7 
         local ok, estimate = llr:estimate(xs[i]:clone(), params)
         if not ok then
            v(string.format('singular k %d i %i', k, i))
         else
            tester:assert(ok)
            local error = actual - estimate
            local absRelativeError = math.abs(error / actual)
            v(string.format(
                 'k %d i %d actual %.2f estimate %.2f err %.2f relErr %.2f',
                 k, i, actual, estimate, error, absRelativeError))
         end
         if i == 6 then
            error()
         end
      end
   end
   tester:assert(fail, 'write a test')
end -- test.two

tester:add(test)
tester:run(true) -- true ==> verbose