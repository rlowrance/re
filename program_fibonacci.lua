-- fibonacci.lua
-- Julia's version of fibonacci(40) takes about 1.1 seconds
-- We find out what lua's version takes

require 'time'

local function fib(n)
   if n < 2 then
      return 2
   else
      return fib(n - 1) + fib(n -2)
   end
end

local n = 40
local cpu, wallclock = time('both', fib, n)
print(string.format('fib %d: cpu %f wallclock %f', n, cpu, wallclock))
