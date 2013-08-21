-- NnwEstimatorKwavg-test.lua
-- unit tests

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

function tests.one()
   --if true then return end
   local v = makeVerbose(false, 'tests.one')
   local nSamples, nDims, xs, ys = makeExample()
   local query = torch.Tensor(nDims):fill(3)
   v('xs', xs)
   v('ys', ys)
   v('query', query)

   local function test(k, expected)
      v('k', k)
      v('expected', expected)
      local knn = NnwEstimatorKwavg(xs, ys, 'epanechnikov quadratic')
      local ok, estimate = knn:estimate(query, k)
      local tol = 1e-3
      tester:assert(ok)
      v('estimate', estimate)
      tester:asserteqWithin(expected, estimate, tol)
   end

   -- see lab book for 2012-10-18 for calculations
   --test(1, 30, false)
   test(3, 30) 
   test(5, 30) 
   test(6, 30)    
   test(7, 32.7275)
   --test(8, 45)
   --test(9, 50)
   --test(10, 55)
end -- one


-- run unit tests
print('*********************************************************************')
tester:add(tests)
tester:run(true)  -- true ==> verbose



   
