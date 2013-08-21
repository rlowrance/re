-- daysPastEpoch-test.lua
-- unit test of daysPastEpoch
-- test on first few items in Obs1/features/day.csv and date.csv
require 'daysPastEpoch'

function check(expected, date)
   local actual = daysPastEpoch(date)
   if expected == actual then return end
   print('expected', expected)
   print('actual', actual)
   assert(expected  == actual)
end

check(  0, 19000101)
check(  1, 19000102)
check( 31, 19000201)
check( 60, 19000301)
check(365, 19001231)
check(366, 19010101)

if false then
check(0, 19720101)
check(1, 19720102)
check(31, 19720201)
check(60, 19720301)
check(365, 19721231)

check(366, 19730101)
end

