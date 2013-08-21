-- keys_test.lua
-- unit test

require 'makeVp'
require 'keys'

vp = makeVp(0)
t1 = {10, 20, abc = 30, def = 40}
vp(1, 't1', t1)

k = keys(t1)
vp(1, 'k', k)

assert(#k == 4)
assert(k[1] == 1)
assert(k[2] == 2)
assert(k[4] == "abc")
assert(k[3] == "def")

print('ok keys_test')