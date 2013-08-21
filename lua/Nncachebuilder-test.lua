-- Nncachebuilder-test.lua
-- unit test

require 'all'

setRandomSeeds(27)

tester = Tester()
test = {}

function test.cache()
   local v, isVerbose = makeVerbose(false, 'test.cache')
   local chatty = isVerbose
   local nObs = 10
   local nDims = 1
   local xs = torch.Tensor(nObs, nDims)
   for i = 1, nObs do
      xs[i][1] = i
   end

   local nShards = 1
   local nncb = Nncachebuilder(xs, nShards)
   local filePathPrefix = '/tmp/Knn-test-cache'
   nncb:createShard(1, filePathPrefix, chatty)
   Nncachebuilder.mergeShards(nShards, filePathPrefix, chatty)
   local cache = Nncache.loadUsingPrefix(filePathPrefix, chatty)
   v('cache', cache)
   if isVerbose then
      local function p(key,value)
         print(string.format('cache[%d] = %s', key, tostring(value)))
      end -- p
      cache:apply(p)
   end

   -- first element should be the obs index
   for i = 1, 10 do
      tester:asserteq(i, cache:getLine(i)[1])
   end

   -- test last element in cache line
   tester:asserteq(10, cache:getLine(1)[10])
   tester:asserteq(10, cache:getLine(2)[10])
   tester:asserteq(10, cache:getLine(3)[10])
   tester:asserteq(10, cache:getLine(4)[10])
   tester:asserteq(10, cache:getLine(5)[10])
   tester:asserteq(1, cache:getLine(6)[10])
   tester:asserteq(1, cache:getLine(7)[10])
   tester:asserteq(1, cache:getLine(8)[10])
   tester:asserteq(1, cache:getLine(9)[10])
   tester:asserteq(1, cache:getLine(10)[10])

end -- test.cache
function test.integrated()
   local v, isVerbose = makeVerbose(false, 'test.integrated')
   local chatty = isVerbose
   v('chatty', chatty)
   local nObs = 300
   local nDims = 10
   local xs = torch.rand(nObs, nDims)
   local nShards = 5

   local nnc = Nncachebuilder(xs, nShards)
   tester:assert(nnc ~= nil)

   local filePathPrefix = '/tmp/Nncache-test'
   for n = 1, nShards do
      nnc:createShard(n, filePathPrefix, chatty)
   end

   Nncachebuilder.mergeShards(nShards, filePathPrefix, chatty)

   local cache = Nncache.loadUsingPrefix(filePathPrefix, chatty)
   --print('cache', cache)
   --print('type(cache)', type(cache))
   v('cache', cache)
   tester:assert(check.isTable(cache))
   local count = 0
   local function examine(key, value)
      count = count + 1
      tester:assert(check.isIntegerPositive(key))
      tester:assert(check.isTensor1D(value))
      tester:asserteq(math.min(nObs,256), value:size(1))
      tester:asserteq(key, value[1]) -- obsIndex always nearest to itself
   end
   cache:apply(examine)
   tester:asserteq(nObs, count)
end -- test.integrated

print('**********************************************************************')
tester:add(test)
tester:run(true)  -- true ==> verbose
