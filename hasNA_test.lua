-- hasNA_test.lua

require 'Dataframe'
require 'hasNA'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- test for Dataframe
local values = {x = {1,2,3},
                y = {11, 12, 13}}

local df = Dataframe{values = values}
vp(1, 'df', df)

assert(not hasNA(df))

df:addColumn('z', {101, Dataframe.NA, 103})
vp(1, 'df with NA', df)
assert(hasNA(df), verbose) -- maybe print

-- test for sequence
local s1 = {1, 2, 3}
assert(not hasNA(s1))
local s2 = {1, Dataframe.NA}
vp(1, 's2', s2)
assert(hasNA(s2, verbose))

-- test for table
local t1 = {x = {1, 2, 3}}
assert(not hasNA(t1))
local t2 = {x = {1, Dataframe.NA}}
vp(1, 't2', t2)
assert(hasNA(t2, verbose))
local t3 = {x = 123, y = 234}
assert(not hasNA(t3))
local t4 = {x = Dataframe.NA, y = 234}
assert(hasNA(t4))
local t5 = {[{1,2}] = {3,4}} -- table with key another table
if verbose > 0 then
   for k, v in pairs(t5) do
      vp(1, 'k', k, 'v', v)
   end
end
assert(not hasNA(t5))
local t6 = {[{Dataframe.NA, 2}] = 23}
assert(hasNA(t6))



-- test for table
print('ok hasNA')