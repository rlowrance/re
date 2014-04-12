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
   local years = Random:integer(nSamples, 1, 2000)
   for queryIndex = 1, nSamples do
      local distances = distanceTime2(years, years[queryIndex])
      for testIndex = 1, nSamples do
         if testIndex == queryIndex then
            assert(distances[testIndex] == 0)
         else
            assert(distances[testIndex] >= 0)
         end
      end
   end
end

test(10)  -- small test


print('ok distanceTime2')
