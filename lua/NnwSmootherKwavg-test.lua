-- NnwSmootherKwavg-test.lua
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
   local v, isVerbose = makeVerbose(false, 'tests.smoother')
   local nSamples, nDims, xs, ys = makeExample()
   
   -- build up the nearest neighbors cache
   local nShards = 1
   local nncb = Nncachebuilder(xs, nShards)
   local filePathPrefix = '/tmp/Nn-test-cache-'
   local chatty = isVerbose
   nncb:createShard(1, filePathPrefix, chatty)
   Nncachebuilder.mergeShards(nShards, filePathPrefix, chatty)
   local cache = Nncache.loadUsingPrefix(filePathPrefix)

   v('cache', cache)

   local function p(key, value)
      print(string.format('cache[%d] = %s', key, tostring(value)))
   end
     
   if isVerbose then
      cache:apply(p)
   end
   
   local visible = torch.ByteTensor(nSamples):fill(0)
   for i = 1, nSamples / 2 do
      visible[i] = 1
   end
   v('visible', visible)
      
   v('xs', xs)
   
   local queryIndex = 5

   local function test(k, expected)
      -- test KnnNnwSmootherKwavg
      local knn = NnwSmootherKwavg(xs, ys, visible, cache, 
                                'epanechnikov quadratic')
      local ok, estimate = knn:estimate(queryIndex, k)
      tester:assert(ok, 'not ok; error message = ' .. tostring(estimate))
      local tol = 1e-2
      v('estimate', estimate)
      tester:asserteqWithin(expected, estimate, tol)
      
   end

   -- hand calculation for expectedKwavg are in lab book 2012-10-20
   if true then
   --test(1, 50)  -- no kwavg estimate for k = 1
      test(2, 50)
      test(3, 45.7143) 
      test(4, 41.8167)
   end
   test(5, 38.0008)
end -- one

-- run unit tests
print('*********************************************************************')
tester:add(tests)
tester:run(true)  -- true ==> verbose



   
