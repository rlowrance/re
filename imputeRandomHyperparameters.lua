-- imputeRandomHyperparameters.lua
-- main program to generate random sets of hyperparameters needed to impute
-- missing features
--
-- INPUT FILES: None
--
-- OUTPUT FILES:
-- imputeRandomHyperparameters.csv
--   randomly generated hyperparamters
--
-- There are 3 hyperparameters with these sampling distributions
-- k     : number of neighbors
--         drawn uniformly from the interval 1, 120
-- mPerYear : meters in one year
--            drawn uniformly from the interval 0 to 10000 (6.2 miles)
-- lambda   : regularization coefficient
--            drawn uniformy form -1 to -5, then transformed by raising 10 to that power
--            hence in the range [.1, .00001]

require 'makeVp'

stop('rework this program to draw geometrically-spaced samples in all ranges')

local function round(x)
   return math.floor(x + 0.5)
end

------------------------------------------
-- MAIN PROGRAM
------------------------------------------

local vp = makeVp(2, 'imputeRandomHyperparameters')
local programName = 'imputeRandomHyperparameters'
local pathOutput = '../data/v6/output/' .. programName .. '.csv'

local output, err = io.open(pathOutput, 'w')
assert(output, err)

-- write CSV header
output:write('set,k,mPerYear,lambda\n')

-- set control parameters for generating the random numbers
local nSets = 100   -- number of sets to generate
local kMin = 1
local kMax = 120

local mPerYearMin = 0
local mPerYearMax = 10000

local lambdaMin = -5
local lambdaMax = -1

for n = 1, nSets do
   local k = round(torch.uniform(kMin, kMax))

   local mPerYear = torch.uniform(mPerYearMin, mPerYearMax)

   local lambdaLog = torch.uniform(lambdaMin, lambdaMax)
   local lambda = 10 ^ lambdaLog
   vp(2, 'lambdaLog', lambdaLog)

   vp(1, 'n', n, 'k', k, 'mPerYear', mPerYear, 'lambda', lambda)

   output:write(tostring(n) .. ',' .. 
                tostring(k) .. ',' .. 
                tostring(mPerYear) .. ',' ..
                string.format('%10.8f', lambda) ..
                '\n')
   --stop()
end

output:close()
print('finished')

