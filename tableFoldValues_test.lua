-- tableFoldValues_test.lua
-- unit test

require 'tableFoldValues'

t = {a = 1, b = 2}

local function addValues(value1, value2)
   return value1 + value2
end

r = tableFoldValues(0, t, addValues)
assert(r == 3)

print('ok tableFoldValues')
