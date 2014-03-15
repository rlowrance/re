-- tableMerge_test.lua
-- unit test

require 'tableMerge'

t1 = {a = 1, b = 2}
t2 = {b = 20, c= 30}

t3 = tableMerge(t1, t2)
assert(t3.a == 1)
assert(t3.b == 20)
assert(t3.c == 30)

print('ok tableMerge')
