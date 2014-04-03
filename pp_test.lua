-- pp_test.lua
-- unit test

require 'makeVp'
require 'pp'

local vp, verboseLevel = makeVp(0, 'tester')

-- unit test pp.table
local actuallyPrint = verboseLevel > 0

if actuallyPrint then
   t1 = {one = 1, abc = 'abc'}
   pp.table('t1', t1)
   pp.table(t1)

   t2 = {def = 'def', nested = t1}
   pp.table('t2', t2)
   pp.table(t2)

   t3 = {}
   t3.one = 1
   t3.f = function() end
   t3.tensor1D = torch.Tensor(30)
   t3.tensor2D = torch.Tensor(3, 5)
   t3.storage = torch.Storage(10)
   pp.table('t3', t3)
end

-- unit test pp.tensor
local verbose = verboseLevel > 0
if verbose then
   local t = torch.rand(10,10)

   pp.tensor('matrix t', t)
   pp.tensor(t, 10)
   pp.tensor(t, 3, 7)

   local v= torch.rand(10)
   pp.tensor('vector', v)
   pp.tensor('vector', v, 3)
end


-- unit test pp.variable
local function f()
   local v123 = 123
   local vabc = 'abc'
   local vTable = {key1 = 'one', key2 = 'abc'}
   local function g(i) end

   if verboseLevel > 0 then
      pp.variable('v123')
      pp.variable('vTable')
   end
end

f()


-- unit test pp.variables
local function f()
   local v123 = 123
   local vabc = 'abc'
   local vTable = {key1 = 'one', key2 = 'abc'}
   local function g(i) end

   if verboseLevel > 0 then
      pp.variables()
   end
end

f()


print('ok pp')
