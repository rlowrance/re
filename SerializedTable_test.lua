-- SerializedTable_test.lua
-- unit test

require 'makeVp'
require 'SerializedTable'

local vp = makeVp(0, 'tester')

local function tableSize(st)
   local vp = makeVp(0, 'tableSize')
   local t = st.table  -- use knowledge of implementation
   vp(1, 'st.table', t)
   local count = 0
   for k, v in pairs(t) do
      vp(2, 'k', k, 'v', v)
      count = count + 1
   end
   vp(1, 'count', count)
   return count
end

local path = '/tmp/SerializedTable_test_file'
local format = 'binary'

do
   local st = SerializedTable(path, format)
   vp(1, 'st', st)

   assert(0 == tableSize(st))

   st:set('one', 1)
   st:set('two', 2)
   assert(2 == tableSize(st))

   assert(1 == st:get('one'))
   assert(2 == st:get('two'))

   st:set('two', 22)
   assert(2 == tableSize(st))
   assert(22 == st:get('two'))

   assert(nil == st:get('three'))

   st:save()
end

do
   local st2 = SerializedTable(path, format)

   local err = st2:load()
   assert(err == nil)

   assert(2 == tableSize(st2))
   assert(1 == st2:get('one'))
   assert(22 == st2:get('two'))

   st2:save()
end

print('ok SerializedTable')
