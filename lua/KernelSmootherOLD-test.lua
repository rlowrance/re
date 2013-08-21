-- KernelSmoother-test.lua
-- unit tests

require 'Distance'
require 'Kernel'
require 'KernelSmoother'
require 'Validations'


myTests = {}
tester = torch.Tester()

--------------------------------------------------------------------------------
-- define weight function
--------------------------------------------------------------------------------

function makeWeight(lambda, distance, kernel)
   function weight(x, y)
      return kernel(x, y, lambda, distance)
   end
   return weight
end

--------------------------------------------------------------------------------
-- convert numbers to Tensors
--------------------------------------------------------------------------------

function toTensor(x)
   if type(x) == 'number' then
      return torch.Tensor(1):fill(x)
   elseif type(x) == 'table' then
      local result = torch.Tensor(#x)
      for i,value in ipairs(x) do
         if torch.typename(x) then
            result[i] = x[i][1]
         else
            result[i] = x[i]
         end
      end
      return result
   else halt(typename(x))
   end
end

function toTensors(...)
   local args = {...}
   local result = {}
   for _, x in pairs(args) do
      print('x', x)
      result[#result + 1] = toTensor(x)
   end
   return result
end

--------------------------------------------------------------------------------
-- assert that two numbers are equal to within delta: math.abs(x-y) <= delta
--------------------------------------------------------------------------------

function assertAlmostEq(x, y, delta, message)
   local diff = x - y
   if math.abs(diff) > delta then 
      print('x y delta', x, y, delta)
   end
   tester:assertle(math.abs(diff), delta, message .. ' not within ' .. delta)
end

--------------------------------------------------------------------------------
-- test3Points
--------------------------------------------------------------------------------

function make3Points()
   local inputs =  toTensors( 0,     0.5,  1)
   local targets =          {-0.92, -0.51, 0.05} -- -1 + x + error
   return inputs, targets
end

function myTests.test3PointsKnn()
   print()
   local inputs, targets = make3Points()
   --print('inputs', inputs)
   --print('targets', targets)
   
   ks = KernelSmoother(inputs, targets)

   -- use default makeNNIndices
   local estimates1 = ks:smoothNearestNeighbors(2,
                                                Distance.euclidean)
   --print('tester', tester)
   tester:asserteq(estimates1[1], (-0.92 - 0.51)/2, 'first')
   tester:asserteq(estimates1[2], (-0.92 - 0.51)/2, 'second')
   tester:asserteq(estimates1[3], (-0.51 + 0.05)/2, 'third')
   --print('estimate default makeNnIndices', estimates1)

   -- supply a makeNNIndices function
   function testMakeNnIndices(query, k, distanceFunction, inputs)
      if query[1] == 0 then return {1, 2}
      elseif query[1] == 0.5 then return {1, 2}
      elseif query[1] == 1 then return {2, 3}
      else error('bad query=' .. query)
      end
   end

   --print('test3PointKnn testMakeNnIndices', testMakeNnIndices)
   local estimates2 = ks:smoothNearestNeighbors(2,
                                                Distance.euclidean,
                                                testMakeNnIndices)
   --print('estimates test makeNNIndices', estimates2)
   tester:asserteq(estimates2[1], (-0.92 - 0.51)/2, 'first')
   tester:asserteq(estimates2[2], (-0.92 - 0.51)/2, 'second')
   tester:asserteq(estimates2[3], (-0.51 + 0.05)/2, 'third')

   -- supply a disk-caching makeNNIndices function
   local cacheReuses = 0
   function makeNnIndicesFunction(cacheFilePath)
      local cache = {}
      function lookup(query)
         local key = tostring(query[1])
         --print('lookup key', key)
         return cache[key]
      end
      
      function save(query, indices)
         local key = tostring(query[1])
         cache[key] = indices
      end
      
      local file = io.open(cacheFilePath, 'r')
      if file then
         file:close()
         function c(a,b,c)
            save(torch.Tensor(1):fill(a), {b,c})
         end
         dofile(cacheFilePath)
         --print('cache from disk', cache)
      else
         cache = {}
      end
      --print('makeNnIndicesFunction cache', cache)
      
      function fromScratch(query)
         local indices = testMakeNnIndices(query, k, distanceFunction, input)
         save(query, indices)
         return indices
      end
      
      function makeNnIndices(query, k, distanceFunction, inputs)
         local maybeIndices = lookup(query)
         if maybeIndices then 
            cacheReuses = cacheReuses + 1
            return maybeIndices 
         else 
            local indices = fromScratch(query)
            return indices
         end
      end
      
      function saveCache()
         file = io.open(cacheFilePath, 'w')
         for k, vs in pairs(cache) do
            --print('k', k)
            --print('vs', vs)
            file:write(string.format('c(%s,%f,%f)\n',
                                     k, vs[1], vs[2]))
         end
         file:close()
         --print('cache written to file', cacheFilePath)
      end
      
      return makeNnIndices, saveCache
   end
   local cacheFilePath = 'KernelSmoother-test-cache.txt'
   local nnFunction, writeCacheToDisk = 
      makeNnIndicesFunction(cacheFilePath)
   -- run test twice, to check if cache works
   local estimates3a = ks:smoothNearestNeighbors(2,
                                                 Distance.euclidean,
                                                 nnFunction)
   tester:asserteq(0, cacheReuses,'no cache values used')
   cacheReuses = 0
   writeCacheToDisk()

   -- use the cache
   local nnFunction, writeCacheToDisk = 
      makeNnIndicesFunction(cacheFilePath)
   
   local estimates3b = ks:smoothNearestNeighbors(2,
                                                 Distance.euclidean,
                                                 nnFunction)
   tester:asserteq(3, cacheReuses, 'all cache values used')
   os.execute('rm ' .. cacheFilePath)

end

function myTests.test3PointsAvg()
   print()
   local trace = false
   local inputs, targets = make3Points()

   ks = KernelSmoother(inputs, targets)
   
   function makeKernel(lambda, distance)
      function kernel(tensor1, tensor2)
         return Kernel.epanechnikov(tensor1, tensor2, lambda, distance)
      end
      return kernel
   end
   local lambda = 0.6
   local estimates = ks:smoothKernelAverage(makeKernel(lambda,
                                                       Distance.euclidean))

   if trace then print('test3PointAvg estimates', estimates) end
   assertAlmostEq(estimates[1], -0.8241, 0.001, 'first')
   assertAlmostEq(estimates[2], -0.4816, 0.001, 'second')
   assertAlmostEq(estimates[3], -0.0811, 0.001, 'third')
end

function myTests.test3PointsLlr()
   print()
   trace = false
   local inputs, targets = make3Points()
   if trace then
      for i,input in ipairs(inputs) do
         print('input', i, input[1])
      end
   end
   if trace then print('targets', targets) end

   ks = KernelSmoother(inputs, targets)
   
   function makeKernel(lambda, distance)
      function kernel(tensor1, tensor2)
         --print('kernel tensor1', tensor1)
         --print('kernel tensor2', tensor2)
         local result = Kernel.epanechnikov(tensor1, tensor2, lambda, distance)
         --print('kernel result', result)
         return result
      end
      return kernel
   end
   local lambda = 0.6
   local estimates = 
      ks:smoothLocalLinearRegression(makeKernel(lambda,
                                                Distance.euclidean))
      
   if trace then print('test3PointLlr estimates', estimates) end
   assertAlmostEq(estimates[1], -0.9201, 0.001, 'first') -- hand calculated
   assertAlmostEq(estimates[2], -0.4816, 0.001, 'second')

   assertAlmostEq(estimates[3], 0.05, 0.001, 'third')
end

-- redo the example in Hastie
--   The Elements of Statistical Learning
--   2001
--   pp. 168 - 172
function myTests.testHastie()
   -- generate data
   local noiseMean = 0
   local noiseStd = 1/3
   local numSamples = 100

   local function f(input)
      local trace = false
      local error = torch.normal(noiseMean, noiseStd)
      if trace then
         print('input', input)
         print('exact', math.sin(4 * input))
         print('error', error)
         print('result', math.sin(4 * input) + error)
      end
      return math.sin(4 * input) + error 
   end

   local inputs = {}
   local targets = {}
   for i=1,numSamples do
      local input = torch.uniform(0,1)
      local target = f(input)
      inputs[#inputs + 1] = torch.Tensor(1):fill(input)
      targets[#targets + 1] = target
   end
   
   --print('inputs', inputs)
   --print('targets', targets)
   local ks = KernelSmoother(inputs, targets)

   -- use Hastie's parameters
   local k = 30
   local distanceFunction = Distance.euclidean
   local lambda = 0.2
   local function kernel(t1, t2)
      return Kernel.epanechnikov(t1, t2, lambda, distanceFunction)
   end
   local estimatesKnn = ks:smoothNearestNeighbors(k,
                                                  distanceFunction)
   local estimatesAvg = ks:smoothKernelAverage(kernel)
   local estimatesLLR = ks:smoothLocalLinearRegression(kernel)

   local sseKnn = 0 -- sum of squared errors for Knn
   local sseAvg = 0
   local sseLLR = 0

   local bestCount = {}
   print()
   print('  i    input   target      knn      avg      LLR  best')
   for i=1,#inputs do
      local absErrorKnn = math.abs(targets[i] - estimatesKnn[i])
      local absErrorAvg = math.abs(targets[i] - estimatesAvg[i])
      local absErrorLLR = math.abs(targets[i] - estimatesLLR[i])
      local best
      if absErrorLLR < absErrorKnn and absErrorLLR < absErrorAvg then
         best = 'LLR'
      elseif absErrorAvg < absErrorKnn and absErrorAvg < absErrorLLR then
         best = 'avg'
      elseif absErrorKnn < absErrorAvg and absErrorKnn < absErrorLLR then
         best = 'knn'
      else best = 'none'
      end
      bestCount[best] = (bestCount[best] or 0) + 1
      sseKnn = sseKnn + absErrorKnn * absErrorKnn
      sseAvg = sseAvg + absErrorAvg * absErrorAvg
      sseLLR = sseLLR + absErrorLLR * absErrorLLR
      print(string.format('%3d %8.4f %8.4f %8.4f %8.4f %8.4f %4s',
                          i, inputs[i][1], targets[i], 
                          estimatesKnn[i], estimatesAvg[i], estimatesLLR[i],
                          best))
   end
   rmseKnn = math.sqrt(sseKnn / #inputs)
   rmseAvg = math.sqrt(sseAvg / #inputs)
   rmseLLR = math.sqrt(sseLLR / #inputs)
   print('rmseKnn', rmseKnn)
   print('rmseAvg', rmseAvg)
   print('rmseLLR', rmseLLR)
   print('Frequency in which had lowest absolute error')
   for k,v in pairs(bestCount) do
      print(k, v)
   end
   tester:assertge(rmseKnn, rmseAvg, 'Knn better than Avg')
   tester:assertge(rmseAvg, rmseLLR, 'Avg better than LLR')
   -- plot the results
   plotInputs = toTensor(inputs)
   plotTargets = toTensor(targets)
   for i=1,10 do
      print(i, plotInputs[i], plotTargets[i])
   end
   -- TODO: add 3 curves
   gnuplot.plot('actuals', plotInputs, plotTargets)
end

--------------------------------------------------------------------------------
-- run unit tests
--------------------------------------------------------------------------------

tester:add(myTests)
tester:run()













