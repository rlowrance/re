-- check-test.lua
-- unit tests

require 'check'
require 'Completion'
require 'IncompleteMatrix'
require 'Log'
require 'Set'
require 'Tester'

tester = Tester()
test = {}

function test.isBoolean()
   tester:assert(check.isBoolean(true))
   tester:assert(check.isBoolean(false))
   tester:assert(not check.isBoolean(1))
   tester:assert(not check.isBoolean(nil))
end

function test:isCompletion()
   local im = IncompleteMatrix()
   im:add(1,2,30)
   im:add(4,5,60)
   local c = Completion(im, 0.001, 20)
   tester:assert(check.isCompletion(c))
   tester:assert(not check.isCompletion(im))
   tester:assert(not check.isCompletion(nil))
end

function test.isFunction()
   tester:assert(check.isFunction(test.isFunction))
   tester:assert(not check.isFunction(1))
   tester:assert(not check.isFunction(nil))
end

function test.isIncompleteMatrix()
   tester:assert(check.isIncompleteMatrix(IncompleteMatrix()))
   tester:assert(not check.isIncompleteMatrix(1))
   tester:assert(not check.isIncompleteMatrix(nil))
end

function test.isInteger()
   tester:assert(check.isInteger(1))
   tester:assert(not check.isInteger(true))
   tester:assert(not check.isInteger(nil))
end

function test.isIntegerNonNegative()
   tester:assert(check.isIntegerNonNegative(0))
   tester:assert(not check.isIntegerNonNegative(-1))
   tester:assert(not check.isIntegerNonNegative(nil))
end

function test.isIntegerPositive()
   tester:assert(check.isIntegerPositive(1))
   tester:assert(not check.isIntegerPositive(0))
   tester:assert(not check.isIntegerPositive(nil))
end

function test.isLog()
   local log = Log('path to file')
   tester:assert(check.isLog(log))
   tester:assert(not check.isLog(IncompleteMatrix()))
   tester:assert(not check.isLog(nil))
end

function test.isNil()
   tester:assert(check.isNil(nil))
   tester:assert(not check.isNil(false))
   tester:assert(not check.isNil(true))
end

function test.isNumber()
   tester:assert(check.isNumber(1))
   tester:assert(not check.isNumber(true))
   tester:assert(not check.isNumber(nil))
end

function test.isNumberNonNegative()
   tester:assert(check.isNumberNonNegative(0))
   tester:assert(not check.isNumberNonNegative(-1))
   tester:assert(not check.isNumberNonNegative(nil))
end

function test.isNumberPositive()
   tester:assert(check.isNumberPositive(1))
   tester:assert(not check.isNumberPositive(0))
   tester:assert(not check.isNumberPositive(nil))
end

function test.isSet()
   tester:assert(check.isSet(Set()))
   tester:assert(not check.isSet(torch.Tensor()))
   tester:assert(not check.isSet(nil))
end

function test.isSequence()
   tester:assert(check.isSequence({}))
   tester:assert(check.isSequence({1}))
   tester:assert(check.isSequence({1,2,3}))
   local t = {}
   t[1] = 1
   t[3] = 3
   tester:assert(not check.isSequence(t))
   t = {1,2,3}
   t.x = 'abc'
   tester:assert(not check.isSequence(t))
   tester:assert(not check.isSequence(nil))
end

function test.isString()
   tester:assert(check.isString('abc'))
   tester:assert(not check.isString(0))
   tester:assert(not check.isString(nil))
end

function test.isTable()
   tester:assert(check.isTable({}))
   tester:assert(check.isTable({1,2,3}))
   tester:assert(not check.isTable(1))
   tester:assert(not check.isTable(nil))
end
                 
function test.isTensor()
   tester:assert(check.isTensor(torch.Tensor(1)))
   tester:assert(check.isTensor(torch.ByteTensor()))
   tester:assert(not check.isTensor({1, 2}))
   tester:assert(not check.isTensor(nil))
end

function test.isTensor1D()
   tester:assert(check.isTensor1D(torch.Tensor(1)))
   tester:assert(not check.isTensor1D(torch.Tensor(2,3)))
   tester:assert(not check.isTensor1D(nil))
end

function test.isTensor2D()
   tester:assert(check.isTensor2D(torch.Tensor(2, 3)))
   tester:assert(not check.isTensor2D(torch.Tensor(10)))
   tester:assert(not check.isTensor2D(nil))
end

function test.isThread()
   local thread = coroutine.create(test.isThread)
   tester:assert(check.isThread(thread))
   tester:assert(not check.isThread(test.isThread))
   tester:assert(not check.isThread(nil))
end
                 
function test.isUserdata()
   tester:assert(check.isUserdata(torch.Tensor()))
   tester:assert(not check.isUserdata({}))
   tester:assert(not check.isUserdata(nil))
end



tester:add(test)
local verbose = true
tester:run(verbose)
