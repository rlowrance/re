-- StandardizeDate-test.lua
-- unit tests

require 'StandardizeDate'
require 'Tester'

test = {}
tester = Tester()

function makeSd()
   local dataDir = '../../data/'
   local obs = '1A'
   local sd = StandardizeDate(dataDir, obs)
   return sd
end -- makeSd

function test:_components()
   local sd = makeSd()
   local result = sd:_components(12345678)
   tester:asserteq(1234, result.year)
   tester:asserteq(56, result.month)
   tester:asserteq(78, result.day)
end -- _components

function test:_daysPastEpoch()
   local sd = makeSd()
   
   sd.epoch = 19700101
   tester:asserteq(0, sd:_daysPastEpoch(19700101))
   tester:asserteq(1, sd:_daysPastEpoch(19700102))
   tester:asserteq(365, sd:_daysPastEpoch(19710101))
end -- _daysPastEpoch

function test:_getDays()
   local sd = makeSd()
   local days = sd:_getDays()
   tester:assert(check.isTensor1D(days))
end -- _getDays()

function test:_getDaysStd()
   local sd = makeSd()
   local daysStd = sd:_getDaysStd()
   tester:assert(check.isTensor1D(daysStd))
end -- _getDays()



function test:_getMuSigma()
   local sd = makeSd()
   
   local days = sd:_getDays()
   local daysStd = sd:_getDaysStd()
   local mu, sigma = sd:_getMuSigma(days[1], daysStd[1],
                                    days[2], daysStd[2])
   -- values hand-calculated in lab book 2012-09-27
   tester:assert(math.abs(mu - 9569.0218) < 0.1)
   tester:assert(math.abs(sigma - 2695.0659) < 0.1)
end -- _getMuSigma

function test:one()
   if true then return end
   tester:assert(false, 'write tests')
end -- one







tester:add(test)
tester:run(true)  -- true ==> verbose output