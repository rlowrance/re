-- assertEq.lua

require 'makeVp'

-- determine if 2 values are equal with a specified tolerance
-- test diff <= tolerance, to allow the tolerance to be zero
function assertEq(a, b, tolerance, verbose)
   -- support verbose == -1 to aid unit testing
   -- if verbose == -1, don't print supplemental error messages
   local verboseValue = verbose
   if verbose == nil or verbose == -1  then
      verboseValue = 0
   end
   local vp = makeVp(verboseValue, 'assertEq')
   vp(1, 'a', a)
   vp(1, 'b', b)
   vp(1, 'tolerance', tolerance)
   assert(tolerance ~= 'nil', 'tolerance is missing or nil')
   assert(type(tolerance) == 'number', 'tolerance is not a number')

   local function check(test, msg, ...)
      if not test then
         if verbose ~= -1 then
            vp(0, msg)
            local varargs = {...}
            --print(msg)
            --print(varargs)
            for i = 1, #varargs, 2 do
               --print(varargs[i])
               vp(0, varargs[i], varargs[i + 1])
            end
         end
         assert(test)
      end
   end

   -- check types
   check(type(a) == type(b),
         'a and b have different types',
         'type(a)', type(a), 'type(b)', type(b))

   -- a and b are numbers
   if type(a) == 'number' then
      check(math.abs(a - b) <= tolerance,
            'a and b differ by more than tolerance',
            'a', a, 'b', b, 'tolerance', tolerance)

   -- a and b are userdata
   elseif type(a) == 'userdata' then
      -- assume a and b are Tensors

      -- check that have same number of dimensions
      check(a:dim() == b:dim(),
            'a and b have different number of dimensions',
            'a:dim()', a:dim(), 'b:dim()', b:dim())

      -- check that each size is equal
      local aSizes = a:size()
      local bSizes = b:size()
      for d = 1, a:dim() do
         check(aSizes[d] == bSizes[d],
               'a and b have different sizes in dimension ' .. d,
               'a:size()', a:size(), 'b:size()', b:size())
      end
         
      -- compare elements
      if a:dim() == 1 then
         -- 1D case
         for i = 1, a:size(1) do
            check(math.abs(a[i] - b[i]) <= tolerance,
                  'a and b differ by more than tolerance in element[' .. 
                     i .. ']',
                  'a[i]', a[i], 'b[i]', b[i], 'tolerance', tolerance)
         end
      elseif a:dim() == 2 then
         -- 2D case
         for i = 1, a:size(1) do
            for j = 1, a:size(2) do
               check(math.abs(a[i][j] - b[i][j]) <= tolerance,
                     'differ by more than tolerance in element[' .. i .. 
                        '][' .. j .. ']',
                     'a[i][j]', a[i][j], 'b[i][j]', b[i][j],
                     'tolerance', tolerance)
            end
         end
      else
         assert('not implemented for more than 2 dimensions', a:dim())
      end
   end
end