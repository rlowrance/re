-- affirm-test.lua
-- unit tests

require 'affirm'
require 'Completion'
require 'Log'
require 'Tester'
require 'Set'

tester = Tester()
test = {}

function test.one()
   local im = IncompleteMatrix()
   im:add(1,1,10)
   local completion = Completion(im, 0.001, 10)
   local log = Log('affirm-test-dummy.file')
   local set = Set()
   local thread = coroutine.create(test.one)

   affirm.isBoolean(true, 'literal')
   affirm.isCompletion(completion, 'completion')
   affirm.isFunction(test.one, 'test.one')
   affirm.isIncompleteMatrix(im, 'im')
   affirm.isInteger(1, 'literal')
   affirm.isIntegerNonNegative(1, 'literal')
   affirm.isIntegerPositive(1, 'literal')
   affirm.isNumber(1, 'literal')
   affirm.isNumberNonNegative(1, 'literal')
   affirm.isNumberPositive(1, 'literal')
   affirm.isSet(set, 'set')
   affirm.isSequence({1}, 'set')
   affirm.isString('abc', 'literal')
   affirm.isTable({1}, 'literal')
   affirm.isTensor(torch.Tensor(), 'literal')
   affirm.isTensor1D(torch.Tensor(1), 'literal')
   affirm.isTensor2D(torch.Tensor(1,2), 'literal')
   affirm.isThread(thread, 'thread')
   affirm.isUserdata(torch.Tensor(), 'literal')
   tester:assert(true, 'nothing raised an error')
end -- one   

tester:add(test)
local verbose = true
tester:run(verbose)