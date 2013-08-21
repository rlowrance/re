-- Nnw-test.lua
-- unit tests for class Nnw

require 'all'

test = {}

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

function test.estimateAvg()
   local v = makeVerbose(false, 'test.estimateAvg')
   local nSamples, nDims, xs, ys = makeExample()

   -- queryIndex == 3
   local nearestIndices = torch.Tensor({5,2,1,3,4,6,7,8,9,10})

   local visible = torch.Tensor(nSamples):fill(0)
   for i = 1, nSamples do
      if i % 2 == 0 then 
         visible[i] = 1
      end
   end
   v('nearestIndices', nearestIndices)
   v('visible', visible)
   v('weights', weights)
   
   function test(k, expected)
      local ok, estimate = Nnw.estimateAvg(xs,
                                          ys,
                                          nearestIndices,
                                          visible,
                                          k)
      tester:assert(ok)
      local tolerance = 1e-5
      tester:asserteqWithin(expected, estimate, tolerance)
   end -- test
   
   test(3, 40)
end -- estimateAvg

function test.estimateKwavg()
   -- Nnw.estimateKwavg is tested by
   --   EstimatorKwavg-test
   --   SmootherKwavg-test
   -- and hence not here
   if true then return end
   local v = makeVerbose(false, 'test.estimateAvg')
   local nSamples, nDims, xs, ys = makeExample()
   local query = torch.Tensor(nDims):fill(3)
   local sortedDistances, sortedIndices = Nnw.nearest(xs, query)

   local visible = torch.Tensor(nSamples):fill(0)
   for i = 1, nSamples do
      if i % 2 == 0 then 
         visible[i] = 1
      end
   end
   v('sortedDistances', sortedDistances)
   v('sortedIndices',sortedIndices)
   v('visible', visible)
   v('weights', weights)
   
   function test(k, expected)
      local lambda = sortedDistances[k]
      local weights = Nnw.weights(sortedDistances, lambda)
      v('lambda', lambda)
      v('weights', weights)
      local ok, estimate = Nnw.estimateKwavg(xs,
                                            ys,
                                            sortedIndices,
                                            visible,
                                            weights, 
                                            k)
      tester:assert(ok)
      local tolerance = 1e-5
      tester:asserteqWithin(expected, estimate, tolerance)
   end -- test
   
   test(3, 46 + 2/3)  -- see lab book 2012-10-23 for hand calculation
   halt()
   test(5, nil)       -- figure this out
end -- estimateKwavg

function test.estimateLlr()
   -- source: http://statmaster.sdu.dk/courses/st111/module03/index.html
   -- price ~ age + area
   local v = makeVerbose(false, 'test.estimateLLr')
   local prices = torch.Tensor({745, 895, 442, 440, 1598}) -- DDK 1000
   local regressors = torch.Tensor({  -- age (in years), area (in m^2)
				      {36, 66}, 
				      {37, 68},
				      {47, 64},
				      {32, 53},
				      {1, 101}})
   v('prices', prices)
   v('regressors', regressors)

   -- all weights the same, all regressors visible
   local nObs = prices:size(1)
   local weights = torch.Tensor(nObs):fill(1)
   local visible = torch.Tensor(nObs):fill(1)

   local sortedNeighborIndices = torch.Tensor(nObs)
   for i = 1, nObs do
      sortedNeighborIndices[i] = i
   end

   local function test(queryIndex)
      local k = 5
      local regularizer = 0
      local ok, estimate = Nnw.estimateLlr(k,
					   regularizer,
					   sortedNeighborIndices,
					   visible,
					   weights,
					   regressors[queryIndex],
					   regressors,
					   prices)
      tester:assert(ok)
      v('estimate', estimate)

      -- the fitted model comes from the source paper
      local function fit(regressor)
	 local x1 = regressor[1]
	 local x2 = regressor[2]
	 local fitted = -281.43 - 7.611 * x1 + 19.01 * x2
	 v('regressor', regressor)
	 v('fitted', fitted)
	 return fitted
      end -- fit
      local fitted = fit(regressors[queryIndex])
      v('fitted', fitted)
      tester:asserteqWithin(estimate, fitted, 0.1)
   end -- test
   
   for queryIndex = 1, nObs do
      test(queryIndex)
   end
end -- estimateLlr

function test.euclideanDistance()
   local nSamples, nDims, xs, ys = makeExample()
   local query = torch.Tensor(nDims):fill(0)

   local function test(xsIndex, expected)
      local tol = 1e-5
      tester:asserteqWithin(expected, 
                            Nnw.euclideanDistance(xs[xsIndex], query), 
                            tol)
   end -- test
   
   test(1, math.sqrt(3))
   test(2, math.sqrt(12))
   test(3, math.sqrt(27))
   test(10, math.sqrt(300))
end -- test.euclideanDistance

function test.euclideanDistances()
   local nSamples, nDims, xs, ys = makeExample()

   local query = torch.Tensor(nDims):fill(0)
   local distances = Nnw.euclideanDistances(xs, query)

   local function test(xsIndex, expected)
      local tol = 1e-5
      tester:asserteqWithin(expected, 
                            distances[xsIndex], 
                            tol)
   end -- test
   
   test(1, math.sqrt(3))
   test(2, math.sqrt(12))
   test(3, math.sqrt(27))
   test(10, math.sqrt(300))
end -- test.euclideanDistances

function test.nearest()
   local v = makeVerbose(false, 'test.nearest')
   local nObs = 3
   local nDims = 1
   local xs = torch.Tensor(nObs, nDims)
   for i = 1, nObs do
      for j = 1, nDims do
         xs[i][j] = i
      end
   end
   
   local query = torch.Tensor(nDims)
   query[1] = 2.1
   
   local sortedDistances, sortedIndices = Nnw.nearest(xs, query)
   v('sortedDistance', sortedDistances)
   v('sortedIndices', sortedIndices)
   
   local tol = 1e-5
   tester:assertlt(math.abs(sortedDistances[1] - 0.1), tol)
   tester:assertlt(math.abs(sortedDistances[2] - 0.9), tol)
   tester:assertlt(math.abs(sortedDistances[3] - 1.1), tol)

   tester:asserteq(2, sortedIndices[1])
   tester:asserteq(3, sortedIndices[2])
   tester:asserteq(1, sortedIndices[3])
end -- nearest

function test.weights()
   local size = 3
   local sortedDistances = torch.Tensor(size)
   for i = 1, size do
      sortedDistances[i] = i
   end
   local lambda = 2
   local weights = Nnw.weights(sortedDistances, lambda)
   
   tester:asserteq(0.5625, weights[1])
   tester:asserteq(0, weights[2])
   tester:asserteq(0, weights[3])
end -- weights

print('*********************************************************************')

tester:add(test)
tester:run(true)  -- true ==> verbose



   
