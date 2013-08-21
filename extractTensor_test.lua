-- extractTensor_test.lua

require 'Dataframe'
require 'extractTensor'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'extractTensor_test')

local table = {a = {1,2,3},
               b = {10, 20, 30},
               c = {100, 200, 300}}

local df = Dataframe{values = table}
if verbose >= 1 then df:print('df') end

local t = extractTensor(df, {'a', 'c'})
vp(1, 't', t)
assert(t:dim() == 2)
assert(t:size(1) == 3)
assert(t:size(2) == 2)
assert(t[1][1] == 1)
assert(t[3][2] == 300)

print('ok extractTensor')

