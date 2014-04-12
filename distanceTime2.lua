-- distanceTime2.lua

require 'makeVp'
require 'pp'

-- return squared time distances from query to every other sample (in units years^2)
-- ARGS:
-- years      : 1D Tensor of year numbers (ex: 1984); size n
-- queryYear  : number
-- RETURNS
-- distances2 : 1D Tensor of size n
function distanceTime2(years, queryYear)
   local n = years:size(1)

   local query1 = torch.Tensor{queryYear}
   local query = torch.Tensor(query1:storage(), 1, n, 0)

   local deltas = years - query
   local result = torch.cmul(deltas, deltas)

   return result
end
