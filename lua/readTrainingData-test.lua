-- readTrainingData-test.lua
-- unit test

require 'Log'
require 'readTrainingData'
require 'Tester'

test = {}
tester = Tester()

function test.limit()
   --if true then print("STUB") ; return end
   local options = {}
   options.dataDir = '../../data/'
   options.inputLimit = 3
   local log = Log('tmp')
   local dropRedundant = false
   
   local obss = {'1A', '2R'}
   for _, obs in ipairs(obss) do
      options.obs = obs
      local n, data = readTrainingData(options,
                                       log,
                                       dropRedundant)
      tester:asserteq(options.inputLimit, n)

      tester:assert(check.isTable(data))

      tester:asserteq(options.inputLimit, data.apns:size(1))
      tester:asserteq(options.inputLimit, data.dates:size(1))
      tester:asserteq(options.inputLimit, data.features:size(1))
      tester:asserteq(options.inputLimit, data.prices:size(1))

      tester:asserteq(2, data.features:nDimension())
   end
      
      
end -- test.limit

function test.drop1OfK()
   local options = {}
   options.dataDir = '../../data/'
   options.debug = 1                   -- means drop all 1 of K encoded cols
   options.inputLimit = 3
   options.obs = '1A'
   local log = Log('/tmp/log-temp-file')
   local dropRedundant = true

   local n, data = readTrainingData(options,
                                    log,
                                    dropRedundant)
   tester:asserteq(options.inputLimit, n)
   tester:asserteq(options.inputLimit, data.features:size(1))
   tester:asserteq(16, data.features:size(2))
end
   


function test.dropRedundant()
   local options = {}
   options.dataDir = '../../data/'
   options.inputLimit = 3
   local log = Log('/tmp/log-temp-file')
   local dropRedundant = true

   local function readFeatures(dropRedundant, obs)
      options.obs = obs
      local n, data = readTrainingData(options,
                                       log,
                                       dropRedundant)
      tester:asserteq(options.inputLimit, n)
      tester:assert(check.isTable(data))
      return data.features
   end
   
   if false then
   local f1AAll = readFeatures(not dropRedundant, '1A')
   tester:asserteq(63, f1AAll:size(2))
   
   local f1ASome = readFeatures(dropRedundant, '1A')
   tester:asserteq(63 - 7, f1ASome:size(2))
   end

   local f2RAll = readFeatures(not dropRedundant, '2R')
   tester:asserteq(20, f2RAll:size(2))
   
   local f2RSome = readFeatures(dropRedundant, '2R')
   tester:asserteq(20 - 2, f2RSome:size(2))
end -- test.dropRedundant


tester:add(test)
tester:run(true)  -- true ==> verbose