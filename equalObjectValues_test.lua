-- equalObjects_test.lua
-- unit test

require 'equalObjects'
require 'makeVp'
require 'NamedMatrix'

local vp = makeVp(0, 'tester')

-- type number
assert(equalObjects(27, 20 + 7))
assert(not equalObjects(27, 28))

-- type boolean
assert(equalObjects(true, true))
assert(equalObjects(false, false))
assert(not equalObjects(true, false))
assert(not equalObjects(false, true))

-- type nil
assert(equalObjects(nil, nil))
assert(not equalObjects(nil, 123))
assert(not equalObjects('abc', nil))

-- type string
assert(equalObjects('abc', 'ab' .. 'c'))
assert(not equalObjects('abc', 'ab'))

-- type function
local function f(x) return x end
assert(equalObjects(f, f))
assert(not equalObjects(f, vp))

-- type table
assert(equalObjects({1,2,3}, {1,2,3}))
local t = {a = 1, b = 2}
assert(equalObjects(t, t))
local t2 = {a = 1, b = 2, c = 3}
assert(not equalObjects(t, t2))

-- torch.typename Tensor
local t = torch.Tensor{1,2,3}
local s = torch.Tensor{1,2,3}
assert(t ~= s)
assert(equalObjects(t, s))
s[1] = 3
assert(not equalObjects(t, s))

-- torch.typename NamedMatrix
local factorLevelsA1 = {'first level for a 1'}
local factorLevelsA4 = {'first level for a 4'}
local nm1 = NamedMatrix{tensor=t, names={'a', 'b', 'c'}, levels=factorLevelsA1}
assert(equalObjects(nm1, nm1))
local nm2 = NamedMatrix{tensor=s, names={'a', 'b', 'c'}, levels=factorLevelsA1}
assert(not equalObjects(nm1, nm2))
local nm3 = NamedMatrix{tensor=t, names={'a', 'b2', 'c'}, levels=factorLevelsA1}
assert(not equalObjects(nm1, nm3))
local nm4 = NamedMatrix{tensor=t, names={'a', 'b2', 'c'}, levels=factorLevelsA4}
assert(not equalObjects(nm1, nm4))

print('ok equalObjects')