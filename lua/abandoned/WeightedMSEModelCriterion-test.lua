-- WeightedMSEModelCriterion-test.lua
-- unit tests

require 'Distance'
require 'Kernel'
require 'Validations'
require 'WeightedMSEModelCriterion'

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
   return torch.Tensor(1):fill(x)
end

function toTensors(...)
   local args = {...}
   local result = {}
   for _, x in pairs(args) do
      result[#result + 1] = toTensor(x)
   end
   return result
end

--------------------------------------------------------------------------------
-- assert that two numbers are equal to within delta: math.abs(x-y) <= delta
--------------------------------------------------------------------------------

function assertEq(x, y, message, delta)
   local diff = x - y
   if Validations.isTensor1D(diff, 'diff') then 
      diff = diff[1]
   end
   Validations.isNumber(diff, 'diff')

   if math.abs(diff) > delta then 
      print('x y delta', x, y, delta)
   end
   tester:assertle(math.abs(diff), delta, message .. ' not within ' .. delta)
end

--------------------------------------------------------------------------------
-- test1
--------------------------------------------------------------------------------



function myTests.test1()
   print()
   local lambda = 0.6
   print('lambda', lambda)
   local myWeight = makeWeight(lambda, Distance.euclidean, Kernel.epanechnikov)

   local xs = toTensors( 0,     0.5,  1)
   local ys = toTensors(-0.92, -0.51, 0.05) -- -1 + x + error
   
   local numDimensions = 1 -- dimensions in each x

   local mc = WeightedMSEModelCriterion(myWeight, xs, numDimensions)
   print('mc', mc)
   print('mc a,b', mc.a, mc.b)
   assertEq(mc:estimate(torch.Tensor(1):fill(0.5)), 
            mc.a + mc.b * toTensor(0.5), 
            'approx', 
            .001)
   assertEq(mc:forward(toTensor(0.5), toTensor(-.5)),'foward', 0.001)
   local loss = mc:forward(toTensor(0.5), toTensor(-0.51))
   print('loss at (0.5,-0.51)', loss)
   print('mc.lastLoss', mc.lastLoss)
   print('mc.lastEstimate', mc.lastEstimate)
end

--------------------------------------------------------------------------------
-- run unit tests
--------------------------------------------------------------------------------

tester:add(myTests)
tester:run()













