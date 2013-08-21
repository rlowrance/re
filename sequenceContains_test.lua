-- sequenceContains_test.lua
-- unit tests of sequenceContains

require 'sequenceContains'

seq = {}
assert(not sequenceContains(seq, 123))

seq = {1, 2, 3}
assert(sequenceContains(seq, 1))
assert(sequenceContains(seq, 2))
assert(sequenceContains(seq, 3))
assert(not sequenceContains(seq, nil))
assert(not sequenceContains(seq, 'a'))
assert(not sequenceContains(seq, true))

print('ok sequenceContains')
