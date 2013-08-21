-- shuffleSequence-test.lua

require 'makeVerbose'
require 'shuffleSequence'
require 'Tester'

test = {}
tester = Tester()

function test.empty()
   seq = {}
   shuffled = shuffleSequence(seq)
   tester:asserteq(0, #shuffled, 'size')
end

function test.oneElement()
   seq = {27}
   shuffled = shuffleSequence(seq)
   tester:asserteq(1, #shuffled, 'size')
   tester:asserteq(27, shuffled[1], '27')
end

function test.manyElements()
   local v = makeVerbose(false, 'test.manyElements')
   local n = 10
   seq = {}
   for i = 1, n do
      seq[#seq + 1] = i
   end

   shuffled = shuffleSequence(seq)
   
   v('seq', seq)
   v('shuffled', shuffled)

   tester:assert(n, #shuffled)

   -- test at at least one element is out of order
   local nChanged = 0
   for i = 1, #shuffled do
      if shuffled[i] ~= i then nChanged = nChanged + 1 end
   end

   tester:assert(nChanged ~= 0, 'at least one changed')
end -- manyElements

function test.manyElementsSeq()
   if false then
      print('STUB')
      return
   end
   local v, trace = makeVerbose(false, 'test.manyElementsSeq')

   seq = { {1,10}, {2,20}, {3,30}, {4,40}, {5,50}}
   shuffled = shuffleSequence(seq)

   local function printseq(s)
      for i = 1, #s do
         print(i, s[i][1], s[i][2])
      end
   end -- printseq

   if trace then
      v('seq') printseq(seq)
      v('shuffled') printseq(shuffled)
   end

   tester:asserteq(5, #shuffled)
   local nChanged = 0
   for i = 1, #shuffled do
      if seq[i][1] ~= shuffled[i][1] or
         seq[i][2] ~= shuffled[i][2]
      then
         nChanged = nChanged + 1
      end
   end
   tester:assert(nChanged ~= 0)
end

tester:add(test)
local verbose = true
tester:run(verbose)