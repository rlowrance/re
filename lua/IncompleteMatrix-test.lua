-- IncompleteMatrix-test.lua
-- unit tests and regression test

require 'checkGradient'
require 'IncompleteMatrix'
require 'Set'
require 'Tester'

tester = Tester()

-- initial random number seeds
local seed = 27
torch.manualSeed(seed)
math.random(seed)

test = {}

--------------------------------------------------------------------------------
-- helper functions
--------------------------------------------------------------------------------

function makeIm()
   local im = IncompleteMatrix()
   im:add(1, 1, 1)
   im:add(2, 3, 6)
   local matrix = torch.Tensor(2, 3):zero()
   matrix[1][1] = 1
   matrix[2][3] = 6
   return im, matrix
end --makeIm

function makeIm123456()
   local im = IncompleteMatrix()
   -- set known entries
   im:add(1,1,1)
   im:add(1,2,2)
   im:add(1,3,3)
   im:add(2,1,4)
   im:add(2,2,5)
   im:add(2,3,6)
   tester:asserteq(im.nElements, 6, '6 elements added')
   -- set known weights
   local rank = 3
   local nRows = 2
   local nColumns = 3
   local nWeightVectors = nRows + nColumns
   local weights = torch.Tensor(nWeightVectors, rank)
   local function set(index, a, b, c)
      weights[index][1] = a
      weights[index][2] = b
      weights[index][3] = c
   end
   set(1, 1, 2, 3)
   set(2, 4, 5, 6)
   set(3, 7, 8, 9)
   set(4, 10, 11, 12)
   set(5, 13, 14, 15)
   return im, weights, rank
end -- makeIm123456

--------------------------------------------------------------------------------
-- unit tests
--------------------------------------------------------------------------------

function test.__init()
   local v = makeVerbose(false, 'test.__init')
   -- test no prespecfied size
   local im = IncompleteMatrix()
   tester:assert(im, 'not constructed')

   -- test size is prespecified and allowed not allowed to grow
   im = IncompleteMatrix(3,5)
   v('im', im)

   tester:asserteq(3, im:getNRows())
   tester:asserteq(5, im:getNColumns())
   tester:asserteq(0, im:getNElements())

   im:add(1,1,100)
   im:add(3,5, 100)
   tester:asserteq(3, im:getNRows())
   tester:asserteq(5, im:getNColumns())
   tester:asserteq(2, im:getNElements())

   local allowError = true
   print('watch')
   local function add(a,b,c,d)
      return im:add(a,b,c,d)
   end
   local ok, added = pcall(add, 4,1,100,true)  -- should generate an error
   v('ok, added', ok, added)
   tester:assert(not ok, 'should have generated an error')
end -- __init

function test.add_1()
   local im = IncompleteMatrix()
   tester:assert(im:add(1,1,1), '1,1 added')
   tester:assert(not im:add(1,1,2), '1 1 already present')
   tester:assert(im:add(3, 4, 12), '3, 4 added')
   tester:asserteq(3, im:getNRows(), '3 rows')
   tester:asserteq(4, im:getNColumns(), '4 cols')
end -- add_1 

function test.add_2()
   local trace = false
   if trace then print('\n') end
   local im = makeIm()
   tester:assert(true, 'add failed to execute')

   -- test adding same value twice
   local x = IncompleteMatrix()
   x:add(1,1, 10)
   x:add(1,1, 20)
   tester:asserteq(1, x.nElements, 'only 1 element')

   --test adding values in different rows but same columns
   local y = IncompleteMatrix()
   tester:assert(true  == y:add(1, 20, 1), 'added')
   tester:assert(true  == y:add(1, 15, 14), 'added')
   tester:assert(false == y:add(1, 20, 10), 'not added')
   tester:assert(true  == y:add(2, 20, 2), 'added')
   tester:assert(true  == y:add(2, 15, 3), 'added') -- originally failed
end -- add_2

function test.averageValue()
   local function check(im, expectedAverageValue)
      local actualAverageValue = im:averageValue()
      tester:asserteq(expectedAverageValue, actualAverageValue)
   end
   
   check(makeIm(), 3.5)
   check(makeIm123456(), 3.5)
end -- averageValue

function test.averageValueBug()
   -- this example led to a bug
   local v = makeVerbose(false, 'test.averageValueBug')
   local im = IncompleteMatrix()
   im:add(1,2,30)
   im:add(4,5,60)
   -- print im.known
   v('im.known', im.known)
   v('im.known[1]', im.known[1])
   v('im.known[2]', im.known[2])
   v('im.known[3]', im.known[3])
   v('im.known[4]', im.known[4])
   
   local av = im:averageValue()
   tester:asserteq(45, av)
end -- averageValueBug

function test.clone()
   local trace = false
   local me = 'test.clone: '
   local im = makeIm()

   local im2 = im:clone()
   if trace then print(me .. 'im2') print(im2) end
   -- make sure all componnents are present
   tester:assert(im2.known ~= nil)
   tester:assert(im2.nColumns ~= nil)
   tester:asserteq(3, im2.nColumns)
   tester:assert(im2.nRows ~= nil)
   tester:asserteq(2, im2.nRows)
   tester:assert(im2.nElements ~= nil)
   tester:asserteq(2, im2.nElements)

   -- mutate the clone and check that original was not changed
   im2:add(10, 10, 100)
   
   tester:assertne(im, im2, 'clone is difference')
   tester:asserteq(2, im.nElements, 'original size')
   tester:asserteq(3, im2.nElements, 'clone size')
end -- clone()

function test.equal()
   -- all elements in each 
   -- sizes are the same
   local im = makeIm()  -- the 1 6 IncompleteMatrix
   local other = im:clone()
   tester:assert(im:equals(other))
   tester:assert(other:equals(im))
   other:add(1,2,27)
   tester:assert(not im:equals(other))
end -- equal

function test.get()
   local im = makeIm()
   
   tester:asserteq(1, im:get(1,1))
   tester:asserteq(6, im:get(2,3))
end -- get

function test.maybeGet()
   local im = makeIm()

   tester:asserteq(1, im:maybeGet(1,1))
   tester:asserteq(6, im:maybeGet(2,3))
   tester:asserteq(nil, im:maybeGet(1,2))
end -- maybeGet

function test.getNColumnss()
   local function check(im, expected)
      assert(im)
      local actual = im:getNColumns()
      tester:assert(actual ~= nil, 'value returned')
      tester:asserteq(expected, actual)
   end
   
   check(makeIm(), 3)
   check(makeIm123456(), 3)
end -- getNCols

function test.getNElements()
   local function check(im, expectedNElements)
      local actualNElements = im:getNElements()
      tester:asserteq(expectedNElements, actualNElements)
   end
   
   check(makeIm(), 2)
   check(makeIm123456(), 6)
end -- getNElements

function test.getNRows()
   local function check(im, expectedNRows)
      local actualNRows = im:getNRows()
      tester:asserteq(expectedNRows, actualNRows)
   end
   
   check(makeIm(), 2)
   check(makeIm123456(), 2)
end -- getNRows


function test.print()
   local trace = false
   if trace then print('\n') end
   local im = makeIm()
   if trace then print('\ntestPrint of im; should print 2 entries') end
   im:print()
   tester:assert(true, 'print method did not finish')
end -- print

function test.printHead()
   local trace = false
   if trace then print('\n') end
   local im = makeIm()
   if trace then print('\ntestPrintHead of im; should print 1 entry') end
   im:printHead(1)
   tester:assert(true, 'printHead method did not finish')
end -- printHead

function test.serializeDeserialize()
   local trace = false
   local im = makeIm()
   local path = 'IncompleteMatrix-serialization-testfile.test'
   
   -- serialize im
   do
      if trace then 
         print('\nim before writing') 
         im:print()
      end

      IncompleteMatrix.serialize(path, im)
      local file = torch.DiskFile(path, 'w')
      file:writeObject(im)
      file:close()

      if trace then
         print('im after writing to disk')
         im:print()
      end
   end

   tester:asserteq(2, im.nElements, '2 elements')

   im:add(1,2,27)
   tester:asserteq(3, im.nElements, '3 elements')

   -- deserialize im
   do
      local anotherIm = IncompleteMatrix.deserialize(path)

      tester:asserteq(2, anotherIm.nElements, '2 elements')
   end
end -- serializeDeserialize

function test.triples()
   local trace = false
   local me = 'test.triples: '

   -- test with makeIm
   local im = makeIm()
   local count = 0
   for i, j, value in im:triples() do
      count = count + 1
      if trace then print(me .. 'i,j,value', i, j, value) end
      if i == 1 and j == 1 then
         tester:asserteq(1, value, '1,1')
      elseif i == 2 and j == 3 then
         tester:asserteq(6, value, '2,3')
      else
         tester:assert(false, 'extra entry found')
      end
   end
   tester:asserteq(2, count)

   -- test with makeIm123456
   im = makeIm123456()
   local count = 0
   for i, j, actual in im:triples() do
      count = count + 1
      if i == 1 then
         if j == 1 then tester:asserteq(1, actual)
         elseif j == 2 then tester:asserteq(2, actual)
         elseif j == 3 then tester:asserteq(3, actual)
         else tester:assert(fail, 'extra column')
         end
      elseif i == 2 then
         if j == 1 then tester:asserteq(4, actual)
         elseif j == 2 then tester:asserteq(5, actual)
         elseif j == 3 then tester:asserteq(6, actual)
         else tester:asser(false, 'extra column')
         end
      else
         tester:assert(false, 'extra row')
      end
   end
   tester:asserteq(6, count)
end -- triples

   

--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------

print('++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++')

if false then
   -- run only one test
   tester:add(test.clone, 'test.clone')
   --tester:add(test.add_1, 'test.add_1')
   --tester:add(test.add_2, 'test.add_2') 
   --tester:add(test.triples, 'test.triples')
else
   tester:add(test)
end
local printUnitTest = true
tester:run(printUnitTest)

print('unit tests finished')
