-- distanceSpace2_test.lua
-- unit test

require 'distanceSpace2'
require 'makeVp'
require 'NamedMatrix'
require 'pp'
require 'Random'
require 'tensor'
require 'torch'


local vp, verboseLevel = makeVp(0, 'distanceSpace2_test')
local debug = verboseLevel > 0

local function test(nSamples)
   local latitudes = Random:integer(nSamples, 0, 90)
   local longitudes = Random:integer(nSamples, -180, 0)

   for queryIndex = 1, nSamples do
      local distances = distanceSpace2(latitudes, longitudes, latitudes[queryIndex], longitudes[queryIndex])
      if debug then print('queryIndex', queryIndex) pp.tensor(distances) end
      for testIndex = 1, nSamples do
         if testIndex == queryIndex then
            assert(distances[testIndex] == 0)
         else
            assert(distances[testIndex] > 0)
         end
      end
   end
end

test(10)

print('ok distanceSpace2')
