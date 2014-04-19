-- tableMapValues_test.lua
-- unit test

require 'pp'
require 'tableMapValues'

local debug = false

local t = {
   'abc',
   inner = {
      dog = 'an animal',
      cat = 'furry animal',
   },
}

local function mapValue(s)
   return s .. 'mapped'
end

if debug then pp.table('t', t) end
local mappedT = tableMapValues(t, mapValue)
if debug then pp.table('mappedT', mappedT) end

assert(mappedT[1] == 'abcmapped')
assert(mappedT.inner.dog == 'an animalmapped')
assert(mappedT.inner.cat == 'furry animalmapped')

print('ok tableMapValues')
