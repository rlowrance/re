-- Set-test.lua

require 'Set'
require 'Tester'

test = {}
tester = Tester()

function makeSet4()
   local result = Set()
   result:add(4)
   return result
end

function makeSet12()
   local result = Set()
   result:add(1)
   result:add(2)
   return result
end

function makeSet123()
   local result = Set()
   result:add(1)
   result:add(2)
   result:add(3)
   return result
end

-- test construction
function test.construction()
   local s = Set()
   tester:assert(s, 'empty set')

   local s123 = makeSet123()
   tester:assert(s123, 's123')

   
   local sAB = Set('a', 'b')
   tester:assert(sAB, 'exists')
   tester:assert(2, sAB:nElements(), 'two elements')
   tester:assert(sAB:hasElement('a'), 'contains string a')
   tester:assert(sAB:hasElement('b'), 'contains string b')
end

function test.add()
   local s = makeSet123()
   tester:assert(s, 's')
end

function seqContains(seq, element)
   for _, seqElement in ipairs(seq) do
      if seqElement == element then
         return true
      end
   end
   return false
end

function test.clone()
   local s = makeSet12()
   local t = s:clone()
   tester:asserteq(2, t:nElements(), 'same size as s')
   tester:assert(t:hasElement(1), 'contains 1')
   tester:assert(t:hasElement(2), 'contains 2')
end

function test.difference()
   local trace = false
   if trace then print('\n') end
   do 
      local s = makeSet123()
      local t = makeSet12()
      if trace then print('s:nElements()', s:nElements()) end
      s:difference(t)
      tester:asserteq(1, s:nElements(), 'one element')
      tester:assert(seqContains(s:elements(), 3), 'only 3')
   end

   if true then return end
   do 
      local s = makeSet123()
      local t = makeSet12()
      t:difference(s)
      tester:asserteq(0, t:nElements(), 'none')
   end

   do
      local s = makeSet123()
      s:difference(s)
      tester:asserteq(0, s:nElements(), 'none')
   end
end

function test.elements()
   local s = makeSet12()
   local elements = s:elements()
   tester:assert(seqContains(elements, 1), '1')
   tester:assert(seqContains(elements, 2), '2')
   tester:assert(not seqContains(elements, 0), 'not 0')
end

function test.elementsSameOrder()
   -- do elements always come out of a set in same order?
   -- NO!
   -- The reason may be that lua's table insertion code has some
   -- randomness to it.
   local trace = true
   local me = 'test.elementsSameOrder: '

   local points = Set()
   points:add('all')
   points:add('random')
   points:add({1,1})
   for i = 1, 10 do
      for _, point in ipairs(points:elements()) do
         if trace then
            print(me .. 'i,point', i, point)
         end
      end
   end
end

function test.equals()
   local s = makeSet12()
   local t = makeSet12()
   tester:assert(s:equals(t), 's equals t')
   tester:assert(t:equals(s), 't equals s')
   local u = makeSet123()
   tester:assert(not s:equals(u), 's not equals u')
   tester:assert(not u:equals(s), 'u not equals s')
end

function test.hasElement()
   local s = makeSet12()
   tester:assert(s:hasElement(1), '1')
   tester:assert(s:hasElement(2), '2')
   tester:assert(not s:hasElement(3), 'not 3')
end

function test.isSet()
   local s = makeSet12()
   tester:assert(Set.isSet(s), 'true')
   local x = {}
   tester:assert(not Set.isSet(x), 'false')
end

function test.nElements()
   local s = Set()
   tester:asserteq(0, s:nElements(), '0')
   tester:asserteq(2, makeSet12():nElements(), '2')
   tester:asserteq(3, makeSet123():nElements(), '3')
end

function test.print()
   local s = makeSet12()
   print('\n')
   s:print()
end

function test.remove()
   local trace = trace
   local s = makeSet12()
   if trace then print('\ns before') s:print() end
   s:remove(1)
   if trace then print('s after') s:print() end
   tester:asserteq(1, s:nElements(), 'one element remains')
   tester:assert(s:hasElement(2), '2 still present')
   tester:assert(not s:hasElement(1), '1 was removed')
end

function test.removeOne()
   local s = makeSet12()

   local removed = s:removeOne()
   tester:asserteq(1, s:nElements(), 'one element remains')
   tester:assert(removed == 1 or removed == 2, 'removed actual element')
   if removed == 1 then
      tester:assert(s:hasElement(2), 'other')
   elseif removed == 2 then
      tester:assert(s:hasElement(1), 'other')
   else
      tester:assert(false, 'can remove only 1 or 2')
   end

   local removed2 = s:removeOne()
   tester:asserteq(0, s:nElements(), 'now empty')
   if removed == 1 then
      tester:asserteq(2, removed2, 'other removed 2')
   elseif removed == 2 then
      tester:asserteq(1, removed2, 'other removed 1')
   else
      tester:assert(false, 'cannot happen')
   end
end

function test.union()
   
   local function test(r)
      tester:asserteq(3, r:nElements(), '3 elements')
      tester:assert(r:hasElement(1), '1')
      tester:assert(r:hasElement(2), '2')
      tester:assert(r:hasElement(3), '3')
   end

   do
      local s1 = makeSet123()
      local s2 = makeSet12()
      s1:union(s2)
      test(s1)
   end

   do
      local s1 = makeSet123()
      local s2 = makeSet12()
      s2:union(s1)
      test(s2)
   end
end

if false then
   tester:add(test.construction, 'test.construction')
   --tester:add(test.clone, 'test.clone')
   --tester:add(test.difference, 'test.difference')
   --tester:add(test.equals, 'test.equals')
   --tester:add(test.union, 'test.union')
else
   tester:add(test)
end
tester:run()