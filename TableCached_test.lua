-- TableCached_test.lua
-- unit test

require 'fileAssureNotExists' 
require 'fileDelete'
require 'TableCached'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

-- construction creating new cache file
local filePath = '/tmp/TableCached_test.csv'

fileAssureNotExists(filePath)
local cf = TableCached(filePath)

-- fetch non-existent key
local found = cf:fetch(123)
vp(1, 'found', found)
assert(not found)

-- store and fetch
cf:store(123, {'abc', 45.6})
cf:store('x', true)
local a = cf:fetch(123)
assert(type(a) == 'table')
assert(a[1] == 'abc')
assert(a[2] == 45.6)

local b = cf:fetch('x')
assert(b == true)

-- iterate
local function containsExpectedValues(tc)
   local vp = makeVp(0, 'containsExpectedValues')
   vp(1, 'tc', tc)
   for k, v in cf:pairs() do
      vp(2, 'k', k, 'v', v)
      if k == 123 then
         assert(v[1] == 'abc')
         assert(v[2] == 45.6)
      elseif k == 'x' then
         assert(v == true)
      else
         assert(false, 'unexpected k')
      end
   end
end

containsExpectedValues(tc)

-- write and read
cf:writeToFile()

cf:reset()  -- empty the table
assert(nil == cf:fetch(123))
assert(nil == cf:fetch('x'))

cf:store('new', 1000)

cf:replaceWithFile()
containsExpectedValues(cf)

-- construction from existing file
local tc2 = TableCached(filePath)

-- make sure expected value are in the table
containsExpectedValues(tc2)

-- finished
print('ok TableCached')

