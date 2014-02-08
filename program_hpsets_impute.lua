-- program_hpsets_impute.lua
-- main program to generate random sets of hyperparameters needed to impute
-- missing features
--
-- See advisory notes for settings of hyperparameters
--
-- INPUT FILES: None
--
-- OUTPUT FILES:
-- hpsets_impute.csv
--   randomly generated hyperparamters
--
-- There are 3 hyperparameters with these sampling distributions
-- k     : number of neighbors
--         drawn uniformly from the interval 2, 120
-- mPerYear : meters in one year
--            drawn geometrically from the interval 0 to 10000 (6.2 miles)
-- lambda   : regularization coefficient
--            drawu uniformly from [.1, .00001]
--            drawn uniformy form -1 to -5, then transformed by raising 10 to that power
--            hence in the range [.1, .00001]

local choiceK = {'uniform', 2, 120}
local choiceLambda = {'uniform', .00001, .1}
local choiceMPerYear = {'geometric', 1, 10000}

require 'makeVp'
require 'Random'

-- return 1D tensor containing a set of randomly-generated hyperparameters
local function generate(nSets, choice)
   local which = choice[1]
   local lowest = choice[2]
   local highest = choice[3]
   if which == 'uniform' then
      return Random():uniform(nSets, lowest, highest)
   elseif which == 'geometric' then
      return Random():geometric(nSets, lowest, highest)
   else
      error('cannot happen ' .. tostring(which))
   end
end

-- write the csv file
local function writeCsvFile(pathOutput, k, lambda, mPerYear)
   local output, err = io.open(pathOutput, 'w')
   assert(output, err)

   -- write CSV header
   output:write('set,k,lambda,mPerYear\n')

   -- write the data records
   for n = 1, k:size(1) do
      output:write(string.format('%d,%d,%f,%f\n', n, k[n], lambda[n], mPerYear[n]))
   end
   output:close()
end

------------------------------------------
-- MAIN PROGRAM
------------------------------------------

local vp = makeVp(2, 'imputeRandomHyperparameters')

-- configure
local programName = 'imputeRandomHyperparameters'
local pathOutput = '../data/v6/output/' .. programName .. '.csv'

local nSets = 100   -- number of sets to generate

local k = generate(nSets, choiceK)
local lambda = generate(nSets, choiceLambda)
local mPerYear = generate(nSets, choiceMPerYear)

writeCsvFile(pathOutput, k, lambda, mPerYear)
print('finished')

