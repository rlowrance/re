-- time_test.lua
-- unit test

require 'makeVp'
require 'time'

local vp = makeVp(1, 'tester')

local function sum(a,b)
   local vp = makeVp(0, 'sum')
   vp(1, 'a', a, 'b', b)
   return a + b
end

local function sumProduct(...)
   local vp = makeVp(0, sumProduct)
   vp(1, '...', {...})
   local args = {...}
   local sum = 0
   local product = 1
   for i, arg in ipairs(args) do
      sum = sum + arg
      product = product * arg
   end
   for i = 1, 1e7 do 
      local a = 1 + 2
   end
   vp(1, 'sum', sum, 'product', product)
   return sum, product
end

local function factorial(n)
   if n == 0 then
      return 1
   else
      return n * factorial(n - 1)
   end
end

local cpu, value = time(sum, 1, 2)
vp(1, 'cpu', cpu, 'value', value)
assert(value == 3)

local cpu, sum, product = time('cpu', sumProduct, 1, 2, 3, 4)
vp(1, 'cpu', cpu, 'sum', sum, 'product', product)
assert(cpu > 0)
assert(sum == 10)
assert(product == 24)

local cpu, fact= time(factorial, 25)
vp(1, 'cpu', cpu, 'fact', fact)
assert(fact > 1.5e25) -- from wikipedia at "Factorial"

local wallclock, fact = time('wallclock', factorial, 25)
vp(1, 'wallclock', wallclock, 'fact', fact)
assert(wallclock > 0)
assert(wallclock >= cpu)  -- expected to use one CPU
assert(fact > 1.5e25)

local cpu, wallclock, fact = time('both', factorial, 25)
vp(1, 'cpu', cpu, 'wallclock', wallclock, 'fact', fact)
assert(wallclock >= cpu)
assert(fact > 1.5e25)

print('ok time')

