-- NnwSmootherAvg-test.lua
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

function tests.smoother()
   --if true then return end
   local v, isVerbose = makeVerbose(false, 'tests.smoother')
   local chatty = isVerbose
   local nSamples, nDims, xs, ys = makeExample()
   
   -- build up the nearest neighbors cache
   local nShards = 1
   local nncb = Nncachebuilder(xs, nShards)
   local filePathPrefix = '/tmp/Nn-test-cache-'
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
      -- test KnnNnwSmootherAvg
      local knn = NnwSmootherAvg(xs, ys, visible, cache)
      local ok, estimate = knn:estimate(queryIndex, k)
      tester:assert(ok)
      tester:asserteq(expected, estimate)
   end

   -- hand calculation for expectedKwavg are in lab book 2012-10-20
   if true then
   test(1, 50)
   test(2, 45) 
   test(3, 40) 
   test(4, 35)
   end
   test(5, 30)
end -- KnnSmoother

-- run unit tests
print('*********************************************************************')
tester:add(tests)

tester:run(true)  -- true ==> verbose



   
