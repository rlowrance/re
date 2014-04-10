--readParcelsForImputatin_test.lua
--unit test

require 'makeVp'
require 'memoryUsed'
require 'pp'
require 'readParcelsForImputation'
require 'Timer'


local vp, verboseLevel = makeVp(0, 'tester')
local debug = verboseLevel > 0

-- test version
local result = readParcelsForImputation('version')
assert(type(result) == 'number')


-- read a few record to make sure everything works
local readlimit = 10
local path = '../data/v6/output/parcels-sfr-geocoded.csv'
local args = {readlimit = readlimit}
local result = readParcelsForImputation('object', path, args)
assert(type(result) == 'table')
if debug then
   print(result.nm.t:size())
   pp.table('result', result)
   vp(2,'nm', nm)
   pp.table('result', result)
   pp.table('result.nm', result.nm)
   pp.tensor('result.nm.t', result.nm.t)
end

-- test reading the entire file
local readlimit = -1
local timer = Timer()
local result = readParcelsForImputation('object', path, {readlimit=readlimit})
local cpu, wallclock = timer:cpuWallclock()
local bytesUsed = memoryUsed()
if debug then print('bytesUsed', bytesUsed) end
assert(type(result) == 'table')
if debug then
   vp(2,'nm', nm)
   vp(2, 'cpu', cpu)
   vp(2, 'wallclock', wallclock)
end
--print('result.nm.t', result.nm.t)
assert(result.nm.t:size(1) > 1.2e6)
if debug then print(result.nm.t:size()) end
assert(result.nm.t:size(2) == 29, tostring(result.nm.t:size()))
assert(type(result.numberColumnNames) == 'table')
assert(type(result.factorColumnNames) == 'table')

print('ok readParcelsForImputation')
