-- Resampling-test.lua
-- unit test of Resampling class

require 'Resampling'
require 'Tester'

myTests = {}

tester = Tester()

--------------------------------------------------------------------------------
-- utilities
--------------------------------------------------------------------------------

function assertNear(actual, expected, delta, msg)
   trace = false
   local me = 'assertNear: '
   if math.abs(actual - expected) >= delta then
      print(me .. 'actual', actual)
      print(me .. 'expected', expected)
      print(me .. 'delta', delta)
   end
   tester:assertlt(math.abs(actual - expected), delta, msg)
end
   
--------------------------------------------------------------------------------
-- test diff2MeansSig
--------------------------------------------------------------------------------

function myTests.diff2MeansConf()
   group1 = {54, 51, 58, 44, 55, 52, 42, 47, 58, 46}
   group2 = {54, 73, 53, 70, 73, 68, 52, 65, 65}
   local low, high = Resampling.diff2MeansConf(group1, group2)
   -- test vs. text book results
   assertNear(low, -17.7, 1,  'lower bound on 90% conf interval')
   assertNear(high, -6.7, 1, 'upper bound on 90% conf interval')
end

--------------------------------------------------------------------------------
-- test diff2MeansSig
--------------------------------------------------------------------------------

function myTests.diff2MeansSig()
   group1 = {54, 51, 58, 44, 55, 52, 42, 47, 58, 46}
   group2 = {54, 73, 53, 70, 73, 68, 52, 65, 65}
   local prob = Resampling.diff2MeansSig(group1, group2)
   -- test vs. text book results
   tester:assertlt(prob, .01, 'probability')

end

--------------------------------------------------------------------------------
-- meanConf
--------------------------------------------------------------------------------

function myTests.meanConf()
   data = {60.2, 63.1, 58.4, 58.9, 61.2, 67.0, 61.0, 59.7, 58.2, 59.8}
   local low, high = Resampling.meanConf(data)
   assertNear(low, 60, 1, 'lower bound on 90% confidence interval')
   assertNear(high, 62, 1, 'upper bound on 90% confidence interval')
end

--------------------------------------------------------------------------------
-- RUN TESTS
--------------------------------------------------------------------------------

tester:add(myTests)
tester:run()