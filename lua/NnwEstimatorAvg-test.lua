-- NnwEstimatorAvg-test.lua
-- unit tests for class NnwEstimatorAvg

require 'all'

tests = {}

tester = Tester()

function makeExample()
   local nsamples = 10
   local ndims = 3
   local xs = torch.Tensor(nsamples, ndims)
   local ys = torch.Tensor(nsamples)
   for i = 1, nsamples do
      for d = 1, ndims do
         xs[i][d] = i
         ys[i] = i * 10
      end
   end
   return nsamples, ndims, xs, ys
end -- makeExample

function tests.estimator()
   --if true then return end
   local v = makeVerbose(false, 'tests.estimator')
   local nSamples, nDims, xs, ys = makeExample()
   local query = torch.Tensor(nDims):fill(3)

   local function test(k, expected)
      --v('xs', xs)
      local knn = NnwEstimatorAvg(xs, ys)
      v('knn', knn)
      local ok, estimate = knn:estimate(query, k)
      v('ok,estimate', ok, estimate)
      tester:assert(ok)
      tester:asserteq(expected, estimate)
   end

   -- see lab book for 2012-10-18 for calculations
   test(1, 30)
   test(3, 30)
   test(5, 30) 
   test(6, 35)    
   test(7, 40)
   test(8, 45)
   test(9, 50)
   test(10, 55)
end -- KnnEstimator

tester:add(tests)
tester:run(true)  -- true ==> verbose



   
