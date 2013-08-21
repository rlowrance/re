-- makeSampleIndexer_test.lua

require 'makeSampleIndexer'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'makeSampleIndexer_test')

torch.manualSeed(123)

local n = 3

local sampleIndex = makeSampleIndexer(n)
local indices1 = {}
for i = 1, 2 * n do
   local index = sampleIndex()
   vp(2, 'index 1', index)
   table.insert(indices1, index)
end

local sampleIndex = makeSampleIndexer(n)
local indices2 = {}
for i = 1, 2 * n do
   local index = sampleIndex()
   vp(2, 'index 2', index)
   table.insert(indices2, index)
end

vp(1, 'indices1', indices1)
vp(1, 'indices2', indices2)


-- For the random seed, the second order differs from the first
for i = 1, n do
   assert(indices1[i] ~= indices2[i])
end

-- Each sequence of indices is periodic
for i = 1, n do
   assert(indices1[i] == indices1[i + n])
   assert(indices2[i] == indices2[i + n])
end

print('ok makeSampleIndexer')
