-- distanceTime2.lua

require 'makeVp'
require 'pp'

-- return squared time distances from query to every other sample (in units years^2)
-- ARGS:
-- features   : NamedMatrix containing column 'YEAR'
-- queryIndex : integer > 0, sample number in features of the query
-- RETURNS
-- distances2 : 1D FloatTensor of size nSamples
--              note that distances2[queryIndex] == 0
function distanceTime2(features, queryIndex)
   local vp, verboseLevel = makeVp(0, 'distanceTimes2')
   local debug = verboseLevel > 0

   vp(1, 'features', features, 'queryIndex', queryIndex)
   local nSamples = features.t:size(1)
   local columnYear = features:columnIndex('YEAR')
   local years = tensor.viewColumn(features.t, columnYear)
   local deltas = years - torch.Tensor(nSamples):fill(features.t[queryIndex][columnYear])
   local result = torch.cmul(deltas, deltas)
   if debug then
      pp.tensor('features.t', features.t)
      pp.tensor('result', result)
   end
   return result:type('torch.FloatTensor')
end
