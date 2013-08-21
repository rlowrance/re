-- ifelse_test.lua
-- unit test of ifelse

require 'ifelse'

assert("a", ifelse(true, "a", 20))
assert(20, ifelse(false, "a", 20))

print('ok ifelse')
