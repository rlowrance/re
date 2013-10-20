-- Sequence2String_test.lua
-- unit test

require 'makeVp'
require 'Sequence2String'

local vp = makeVp(0, 'unit test')

local ss = Sequence2String{types={'string', 'number'}, separator='-'}

local str = ss:toString({'abc', 123})
vp(1, 'str', str)
assert(str == 'abc-123')

local seq = ss:toSequence(str)
vp(1, 'seq', seq)
assert(seq[1] == 'abc')
assert(seq[2] == 123)

print('ok Sequence2String')

