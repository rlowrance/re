-- splitString_test.lua
-- unit tests of splitString

require 'splitString'

local x = 'a,b,c'
local splitStringX = splitString(x, ',')
assert(splitStringX[1] == 'a')
assert(splitStringX[2] == 'b')
assert(splitStringX[3] == 'c')

local y = ',,'
local splitStringY = splitString(y, ',')
assert(splitStringY[1] == '')
assert(splitStringY[2] == '')
assert(splitStringY[3] == '')

local z = 'a,,c'
local splitStringZ = splitString(z, ',')
assert(splitStringZ[1] == 'a')
assert(splitStringZ[2] == '')
assert(splitStringZ[3] == 'c')

-- check tab separated values
local w = 'a\tb\t'
local splitStringW = splitString(w, '\t')
assert(splitStringW[1] == 'a')
assert(splitStringW[2] == 'b')
assert(splitStringW[3] == '')

print('ok splitString')
