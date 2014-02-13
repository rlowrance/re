-- tableCopy_test.lua
-- unit test

require 'equalObjectValues'
require 'makeVp'
require 'tableCopy'

local t = {
   x = 'one',
   b = 'two',
   c = {a = "a string", b = "b string"},
}

t[{1,2}] = 'seq 1 2'


local copy = tableCopy(t)
assert(equalObjectValues(copy, t))

print('ok tableCopy')
