-- SerializedTable_test.lua
-- unit test

require 'makeVp'
require 'SerializedTable'

local vp = makeVp(2, 'tester')

local path = '/tmp/SerializedTable_test_file'
local format = 'binary'

local st = SerializedTable(path, format)
vp(1, 'st', st)

local function tableSize(st)
   local t = st.table  -- use knowledge of implementation
   local count = 0
   for k, v in pairs(t) do
      count = count + 1
   end
   return count
end

assert(0 == tableSize(st))

st:set('one', 1)
st:set('two', 2)
assert(2 == tableSize(st))

assert(1 == st:get('one'))
assert(2 == st:get('two'))

st:set('two', 22)
assert(2 == tableSize(st))
assert(22 == st:get())

assert(nil == st:get('three'))

st:save()

local st2 = SerializedTable(path, format)
local err = st:load()
assert(err == nil)

assert(2 == tableSize(st2))
assert(1 == st2:get('one'))
assert(22 == st2:get('two'))

st:save()
print('ok SerializedTable')
