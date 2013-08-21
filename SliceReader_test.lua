-- unit test of SliceReader

require 'makeVp'
require 'SliceReader'

-- write the temp file used for testing
local filename = '/tmp/SliceReader-test-file.txt'
local records = {'1', '2', '3', '4', '5'}

local f = io.open(filename, 'w') 
assert(f ~= nil)
for _, record in ipairs(records) do
   f:write(record .. '\n')
end
f:close()

local function compare(a,b)
   local vp = makeVp(0, 'compare')
   vp(1, 'a', a)
   vp(1, 'b', b)
   assert(a == b)
end

-- test reading each record
local f = io.open(filename, 'r')
assert(f ~= nil)
local sr = SliceReader(f, 1, 1) -- read each record
compare(sr:next() , '1')
compare(sr:next() , '2')
compare(sr:next() , '3')
compare(sr:next() , '4')
compare(sr:next() , '5')
compare(sr:next() , nil)
f:close()

-- test reading in 3 slices
local f = io.open(filename, 'r')
assert(f ~= nil)
local sr = SliceReader(f, 1, 3) -- read slice 1
compare(sr:next() , '1')
compare(sr:next() , '4')
compare(sr:next() , nil)
f:close()


local f = io.open(filename, 'r')
assert(f ~= nil)
local sr = SliceReader(f, 2, 3) -- read slice 2
compare(sr:next() , '2')
compare(sr:next() , '5')
compare(sr:next() , nil)
f:close()

local f = io.open(filename, 'r')
assert(f ~= nil)
local sr = SliceReader(f, 3, 3) -- read slice 3
compare(sr:next() , '3')
compare(sr:next() , nil)
f:close()

-- test forEachRecord
local n = 0
local function action(record)
   n = n + 1
   if n == 1 then 
      assert(record == '2')
   elseif n == 2 then
      assert(record == '5')
   else
      error('bad n = ' .. tostring(n))
   end
end

local f = io.open(filename, 'r')
assert(f ~= nil)
local sr = SliceReader(f, 2, 3) -- read slice 2
local nRead = sr:forEachRecord(action)
assert(nRead == 2)
f:close()

print('ok SliceReader')

