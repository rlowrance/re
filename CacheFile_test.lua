-- CacheFile_test.lua
-- unit test

require 'CacheFile'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'tester')

local filePath = '/tmp/CacheFile_test.csv'
local cf = CacheFile{keyNames={'key1', 'key2', 'key3'},
                     valueNames={'string1', 'number2'},
                     filePath=filePath}

local found = cf:fetch{keys={123, 'abc', .789}}
vp(1, 'found', found)
assert(not found)

local already = cf:store{keys={123, 'abc', .789},values={'x',27}}
assert(not already)

local already = cf:store{keys={123, 'abc', .789},values={'x',27}}
assert(already)

local ok, msg = pcall(function(x) cf:store(x) end,
                      {keys={123, 'abc', .789},values={'new', 'value'}})
vp(1, 'ok', ok, 'msg', msg)
assert(not ok)
vp(2, 'match',string.match(msg, 'keys in table with different value'))
assert(string.match(msg, 'keys in table with different value'))

local values = cf:fetch{keys={123, 'abc', .789}}
assert(values)
assert(values[1] == 'x')
assert(values[2] == 27)
assert(#values == 2)

-- test large number of entries
local c = CacheFile{keyNames={'k1', 'k2', 'k3'},
                    valueNames={'x'},
                    filePath=filePath}
local key1s = {1, 2, 3}
local key2s = {10, 11, 12}
local key3s = {100, 101, 102}
for _, key1 in ipairs(key1s) do
   for _, key2 in ipairs(key2s) do
      for _, key3 in ipairs(key3s) do
         local value = key1 + key2 + key3
         c:store{keys={key1, key2, key3}, values={value}}
      end
   end
end
-- test retrieval
for _, key1 in ipairs(key1s) do
   for _, key2 in ipairs(key2s) do
      for _, key3 in ipairs(key3s) do
         local expected = key1 + key2 + key3
         local actual = c:fetch{keys={key1, key2, key3}}
         assert(#actual == 1)
         vp(1, 'expected', expected, 'actual', actual)
         assert(actual[1] == expected)
      end
   end
end

-- test writing and reading
c : write()
-- create new cache file with one entry, not in old c
local c = CacheFile{keyNames={'k1', 'k2', 'k3'},
                    valueNames={'x'},
                    filePath=filePath}
c:store{keys={0,0,0},values={0}}

c:merge()  -- add in all the key-value pairs written from old c

-- make sure the old values are now there
for _, key1 in ipairs(key1s) do
   for _, key2 in ipairs(key2s) do
      for _, key3 in ipairs(key3s) do
         local expected = key1 + key2 + key3
         local actual = c:fetch{keys={key1, key2, key3}}
         assert(#actual == 1)
         vp(1, 'expected', expected, 'actual', actual)
         assert(actual[1] == expected)
      end
   end
end

-- make sure the new value is also there
local expected = 0
local actual = c:fetch{keys={0,0,0}}
vp(1, 'actual', actual)
vp(1, 'c.table', c.table)
assert(actual ~= nil)
assert(#actual == 1)
assert(actual[1] == expected)

print('ok CacheFile')