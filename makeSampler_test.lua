-- makeSampler_test.lua

require 'makeSampler'
require 'makeVp'

local verbose = 0
local vp = makeVp(verbose, 'makeSampler_test')

torch.manualSeed(123)

local xs = torch.Tensor{{1, 2, 3},
                        {10, 20, 30},
                        {100, 200, 300}}
local ys = torch.Tensor{-1, -2, -3}
local zs = torch.Tensor{.1, .2, .3}
local n = xs:size(1)

vp(1, '2 values')
local sample = makeSampler(xs, ys)
local ys1 = {}
for i = 1, 2 * n do
   local x, y = sample()
   vp(1, 'next sample x', x)
   vp(1, 'next sample y', y)
   table.insert(ys1, y)
end

vp(1, '3 values')
local sample = makeSampler(xs, ys, zs)
local ys2 = {}
for i = 1, 2 * n do
   local x, y, z = sample()
   vp(1, 'next sample x', x)
   vp(1, 'next sample y', y)
   vp(1, 'next sample z', z)
   table.insert(ys2, y)
end

-- For the random seed, the second order differs from the first
for i = 1, n do
   assert(ys1[i] ~= ys2[i])
end

print('ok makeSampler')
