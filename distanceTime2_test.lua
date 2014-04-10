-- distanceTime2_test.lua
-- unit test

require 'distanceTime2'
require 'makeVp'
require 'NamedMatrix'
require 'Random'
require 'tensor'
require 'torch'


local vp, verboseLevel = makeVp(0, 'distanceTime2_test')
local debug = verboseLevel > 0
torch.manualSeed(123)

local function makeFeatures(nSamples)
   return NamedMatrix{
      tensor = tensor.viewAs2D(Random():integer(nSamples, 1, 100)),
      names = {'YEAR'},
      levels = {},
   }
end

local function test(nSamples)
   local features = makeFeatures(nSamples)
   local queryIndex = nSamples
   features.t[queryIndex][1] = 0  -- make debugging easier
   local distance2 = distanceTime2(features, queryIndex)
   if debug then 
      print('queryIndex', queryIndex)
      for i = 1, nSamples do
         print(string.format('index %2d year %4d distance^2 %4d', i, features.t[i][1], distance2[i]))
         if i >= 99 then break end
      end
   end
   assert(distance2[queryIndex] == 0)
end

test(10)  -- small test
test(1.2e6)  -- large test

print('ok distanceTime2')
