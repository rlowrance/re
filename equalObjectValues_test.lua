-- equalObjectValues_test.lua
-- unit test

require 'equalObjectValues'
require 'makeVp'
require 'NamedMatrix'

local vp = makeVp(0, 'tester')

local function assertEqual(a, b)
   local vp = makeVp(0, 'assertEqual')
   vp(1, 'a', a, 'b', b)
   local result, whynot = equalObjectValues(a, b)
   vp(2, 'result', result, 'whynot', whynot)
   assert(result, whynot)
end

local function assertNotEqual(a, b)
   local result, whynot = equalObjectValues(a, b)
   assert(not result)
end
   
-- torch.typename Tensor
local t = torch.rand(3, 4)
local s = t:clone()
vp(1, 't', t, 's', s)
assertEqual(t, s)
s[1][2] = t[1][2] + 1
vp(1, 't', t, 's', s)
assertNotEqual(t, s)

local t = torch.Tensor{1,2,3}
local s = torch.Tensor{1,2,3}
assert(t ~= s)
assertEqual(t, s)
s[1] = 3
assertNotEqual(t, s)

-- type number
assertEqual(27, 20 + 7)
assertNotEqual(27, 28)

-- type boolean
assertEqual(true, true)
assertEqual(false, false)
assertNotEqual(true, false)
assertNotEqual(false, true)

-- type nil
assertEqual(nil, nil)
assertNotEqual(nil, 123)
assertNotEqual('abc', nil)

-- type string
assertEqual('abc', 'ab' .. 'c')
assertNotEqual('abc', 'ab')

-- type function
local function f(x) return x end
assertEqual(f, f)
assertNotEqual(f, vp)

-- type table
assertEqual({1,2,3}, {1,2,3}) -- check sequence
assertNotEqual({1,2,3},{1,3,2})

local t = {a = 1, b = 2}  -- check general table
assertEqual(t, t)
local t2 = {a = 1, b = 2, c = 3}
assertNotEqual(t, t2)


print('ok equalObjectValues')
