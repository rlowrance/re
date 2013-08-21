-- ModelIndex-test.lua
-- unit test

require 'all'

test = {}
tester = Tester()

function test.obs1A()
   -- first 10 entries from kappa in obs 1A
   local kappa = {4,4,4,1,1,1,1,4,4,5}
   local mi = ModelIndex(kappa)

   -- check global index to fold index conversions
   tester:asserteq(1, mi:globalToFold(1))
   tester:asserteq(2, mi:globalToFold(2))
   tester:asserteq(3, mi:globalToFold(3))
   tester:asserteq(1, mi:globalToFold(4))

   tester:asserteq(2, mi:globalToFold(5))
   tester:asserteq(3, mi:globalToFold(6))
   tester:asserteq(4, mi:globalToFold(7))

   tester:asserteq(4, mi:globalToFold(8))
   tester:asserteq(5, mi:globalToFold(9))

   tester:asserteq(1, mi:globalToFold(10))

   -- check fold index to global index conversions
   tester:asserteq(1, mi:foldToGlobal(4, 1)) -- fold 4 index 1
   tester:asserteq(2, mi:foldToGlobal(4, 2)) -- fold 4 index 2
   tester:asserteq(3, mi:foldToGlobal(4, 3)) -- fold 4 index 3
   tester:asserteq(8, mi:foldToGlobal(4, 4)) -- fold 4 index 4
   tester:asserteq(9, mi:foldToGlobal(4, 5)) -- fold 4 index 5

   tester:asserteq(4, mi:foldToGlobal(1, 1)) -- fold 1 index 1
   tester:asserteq(5, mi:foldToGlobal(1, 2)) -- fold 1 index 2
   tester:asserteq(6, mi:foldToGlobal(1, 3)) -- fold 1 index 3
   tester:asserteq(7, mi:foldToGlobal(1, 4)) -- fold 1 index 4
   
   tester:asserteq(10, mi:foldToGlobal(5, 1)) -- fold 5 index 1
end -- test.obs1A

function test.sequential()
   -- 10 items assigned sequential to folds
   local kappa = {1,2,3,4,5,1,2,3,4,5}
   local mi = ModelIndex(kappa)
   tester:asserteq(1, mi:globalToFold(1))
   tester:asserteq(1, mi:globalToFold(2))
   tester:asserteq(1, mi:globalToFold(3))
   tester:asserteq(1, mi:globalToFold(4))
   tester:asserteq(1, mi:globalToFold(5))

   tester:asserteq(2, mi:globalToFold(6))
   tester:asserteq(2, mi:globalToFold(7))
   tester:asserteq(2, mi:globalToFold(8))
   tester:asserteq(2, mi:globalToFold(9))
   tester:asserteq(2, mi:globalToFold(10))
end -- test.sequential

function test.random()
   local v = makeVerbose(false, 'tests.random')
   local kappa = {1,2,3,4,5,1,2,3,4,5}
   setRandomSeeds()
   kappa = shuffleSequence(kappa)
   v('kappa', kappa)
   local mi = ModelIndex(kappa)
   tester:asserteq(1, mi:globalToFold(1))  -- 4
   tester:asserteq(1, mi:globalToFold(2))  -- 5
   tester:asserteq(1, mi:globalToFold(3))  -- 2
   tester:asserteq(1, mi:globalToFold(4))  -- 3
   tester:asserteq(2, mi:globalToFold(5))  -- 5
   tester:asserteq(2, mi:globalToFold(6))  -- 2
   tester:asserteq(1, mi:globalToFold(7))  -- 1
   tester:asserteq(2, mi:globalToFold(8))  -- 3
   tester:asserteq(2, mi:globalToFold(9))  -- 1
   tester:asserteq(2, mi:globalToFold(10)) -- 4
end -- test.random

tester:add(test)
tester:run(true) -- true ==> verbose