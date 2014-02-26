-- Objectivefunction_test.lua
-- unit test

require 'Objectivefunction'
require 'printTableValue'

local of = Objectivefunction()

-- check that we count number of function calls correctly
of:initialTheta()

for i = 1, 2 do 
   of:gradient()
end

for i = 1, 3 do 
   of:loss()
end

for i = 1, 4 do
   of:lossGradient()
end

for i = 1, 5 do
   of:predictions()
end

local nCalls = of:getNCalls()
printTableValue('of', of)
printTableValue('nCalls', nCalls)

assert(nCalls.initialTheta == 1)
assert(nCalls.gradient == 2)
assert(nCalls.loss == 3)
assert(nCalls.lossGradient == 4)
assert(nCalls.getNCalls == 1)
assert(nCalls.predictions == 5)

-- cannot do anything else because class is abstract

print('ok Objectivefunction')

