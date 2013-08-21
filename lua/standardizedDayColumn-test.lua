-- standardizedDayColumn-test.lua
-- unit test

require 'standardizedDayColumn'
require 'Tester'

test = {}
tester = Tester()

function test.one() 
   local dataDir = '../../data/'

   local obss = {'1A', '2R'}
   for _, obs in pairs(obss) do
      local col = standardizedDayColumn(dataDir, obs)
      tester:asserteq(6, col)
   end
end -- test.one

tester:add(test)
tester:run(true) -- true ==> verbose