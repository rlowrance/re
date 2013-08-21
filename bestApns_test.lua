-- bestApns_test.lua
-- unit test of bestApns

require 'bestApns'

local na = {}
local unformatted = {'111',  '2-2x', na,     na}
local formatted   = {'1-23', '2-22', '3-33', na}
local result = bestApns{formattedApns = formatted
                        ,unformattedApns = unformatted
                        ,na =  na
                       }
assert(result[1] == 111)
assert(result[2] == 222)
assert(result[3] == 333)
assert(result[4] == na)

print('ok bestApns')
 