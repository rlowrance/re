-- Tester.lua
-- a facade for torch.Testor with these additional capabilities
-- 1. Can specify that the unit test run stops with an error on the first 
--    failure. The error gives a full stack trace, useful for figuring out
--    why a test failed.
-- 2. Can leave off the message on each test. A default value is supplied.

-- Usage idea
-- 1. Write enough of the new function to write a unit test.
-- 2. Write unit test for the function.
-- 3. Run the unit test, expecting failure.
-- 4. Iteratively improve the function and run the unit test.
-- 5. If you are running just the unit test for the new function,
--    run all the unit tests at the end.

-- API overview
if false then
   tester = Tester()

   test = {}

   function test.XYZablDEF123()  -- weird name, because cannot make it local
      tester:assert(boolean ,message)  -- message is always optional
      tester:asserteq(val, condition, message)
      tester:asserteqWithin(val, condition, tolerance, message)
      tester:assertge(val, condition, message)
      tester:assertgt(val, condition, message)
      tester:assertle(val, condition, message)
      tester:assertle(val, condition, message)
      tester:assertne(val, condition, message)
      tester:assertTensorEq(ta, tb, condition, message) -- norm(ta - tb) < cond
   end
  
   -- adding test cases
   tester:add(test.one, 'test.one')  -- add one test
   tester:add(test)                  -- add all tests in table
   tester:run(verbose, name)         -- if true, print trace of execution
                                     -- if false and name provide, print ok name
end -- API overview

local Tester = torch.class('Tester')

--------------------------------------------------------------------------------
-- construction
--------------------------------------------------------------------------------

function Tester:__init()
   self.tests = {}
   self.nPassed = 0
end -- __init

--------------------------------------------------------------------------------
-- public methods
--------------------------------------------------------------------------------

function Tester:add(f, name)
   local trace = false
   local me = 'Tester:add '

   if trace then
      print(me .. 'f', f)
      print(me .. 'name', name)
   end

   assert(f, 'missing function')
   if type(f) == 'function' then
      assert(name)
      self.tests[#self.tests + 1] = {f, name}
   elseif type(f) == 'table' then
      assert(name == nil)
      for name, f in pairs(f) do
         if trace then
            print(me .. 'table f', f)
            print(me .. 'table name', name)
         end
         assert(name)
         assert(type(name) == 'string')
         assert(f)
         assert(type(f) == 'function')
         self.tests[#self.tests + 1] = {f, name}
      end
   else
      error('type of f must be function or table, is ' .. type(f))
   end
end -- add

function Tester:assert(val, message)
   if val == nil then
      assert('missing val')
   end
   self:_check(val, '', val, nil, message)
end -- assert

function Tester:asserteq(val, condition, message)
   -- don't check for missing arguments as nil values are OK
   self:_check(val == condition, 'eq', val, condition, message)
end -- asserteq

function Tester:asserteqWithin(val, condition, tolerance, message)
   assert(type(val) == 'number', 
	  string.format('val (=%s) is not a number', tostring(val)))
   assert(type(condition) == 'number', 
	  string.format('condition (=%s) is not a number', tostring(condition)))
   assert(type(tolerance) == 'number', 
	  string.format('tolerance (=%f) is not a number', tostring(tolerance)))
   -- replicate a call to self:_check but with an extra parameter
   if math.abs(val - condition) < tolerance then
      self.nPassed = self.nPassed + 1
   else
      local message = message or 'no message'
      local a = 'unit test asserteqWithin failed\n'
      local b = ' val: ' .. tostring(val) .. '\n'
      local c = ' condition: ' .. tostring(condition) .. '\n'
      local d = ' tolerance: ' .. tostring(tolerance) .. '\n'
      local e = ' message: ' .. message .. '\n'
      error(a .. b .. c .. d .. e)
   end
end -- assertEqWithin

function Tester:assertge(val, condition, message)
   assert(val, 'missing val')
   assert(condition, 'missing condition')
   self:_test(val >= condition, 'ge', val, condition, message)
end -- assertge

function Tester:assertgt(val, condition, message)
   assert(val, 'missing val')
   assert(condition, 'missing condition')
   self:_check(val > condition, 'gt', val, condition, message)
end -- assertgt

function Tester:assertle(val, condition, message)
   assert(val, 'missing val')
   assert(condition, 'missing condition')
   self:_check(val <= condition, 'le', val, condition, message)
end -- assertle

function Tester:assertlt(val, condition, message)
   assert(val, 'missing val')
   assert(condition, 'missing condition')
   self:_check(val < condition, 'lt', val, condition, message)
end -- assertlt

function Tester:assertne(val, condition, message)
   assert(val, 'missing val')
   assert(condition, 'missing condition')
   self:_check(val ~= condition, 'ne', val, condition, message)
end -- assertne

function Tester:assertTensorEq(ta, tb, condition, message)
   assert(ta, 'missing Tensor a')
   assert(tb, 'missing Tensor b')
   assert(condition, 'missing condition')
   local norm = torch.norm(ta - tb)
   self:_check(norm < condition, 'TensorEq', val, condition, message)
end -- assertTensorEq

function Tester:run(verbose, name)
   local trace = false
   if verbose ~= nil then
      if type(verbose) ~= 'boolean' then
         error('type of verbose must be boolean; is ' .. type(verbose))
      end
      trace = verbose
   end
   local me = 'Tester:run '
   if trace and false then
      print(me .. 'self', self)
   end
   local count = 0
   for i = 1, #self.tests do
      local f = self.tests[i][1]
      local name = self.tests[i][2]
      if trace then
         print(string.format('Tester:run RUNNING %s', name))
      end
      f() -- this call will generate an error if the test fails
      count = count + 1
   end

   if not verbose and name ~= nil then
      print('ok ' .. name)
   else
      print(string.format('Tester:run RAN %d UNIT TESTS FUNCTIONS ' ..
                          'WITH %d ASSERTIONS WITHOUT AN ERROR',
                          count, self.nPassed))
   end
end -- run

--------------------------------------------------------------------------------
-- private methods
--------------------------------------------------------------------------------

function Tester:_check(testResult, nameSuffix, val, condition, message)
   if testResult then
      self.nPassed = self.nPassed + 1 
   else
      self:_fail(nameSuffix, val, condition, message)
   end
end

function Tester:_fail(nameSuffix, val, condition, message)
   message = message or 'no message'
   local a = 'unit test assert' .. nameSuffix .. ' failed\n'
   local b = ' val: ' .. tostring(val) .. '\n'
   local c = ' condition: ' .. tostring(condition) .. '\n'
   local d = ' message: ' .. message
   error(a .. b .. c .. d)
end

