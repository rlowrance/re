-- makeFittedDataSelector-test.lua

require 'all'

test = {}
tester = Tester()

function test.one()
   local fold = 1
   local kappa = {1,2,3,1,2,3,1,2,3,1}

   local function check(fold, expectedSelector)
      local selector = makeFittedDataSelector(fold, kappa)
      tester:asserteq(10, selector:size(1))
      for i = 1, #expectedSelector do
         tester:asserteq(expectedSelector[i], selector[i])
      end
   end

   check(1, {0,1,1,0,1,1,0,1,1,0})
   check(2, {1,0,1,1,0,1,1,0,1,1})
   check(3, {1,1,0,1,1,0,1,1,0,1})
end -- test.one

tester:add(test)
tester:run(true)  -- true ==> verbose