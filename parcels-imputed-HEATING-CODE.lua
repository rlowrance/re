-- parcels-imputed-HEATING-CODE.lua
-- main program to impute HEATING.CODE
-- INPUT FILES
-- OUTPUT/parcels-sfr-geocoded.csv 
--   all SFR parcels that can be geocode
-- OUTPUT FILES
-- OUTPUT/parcels-imputed-HEATING-CODE.csv
--   imputed codes for only parcels with missing codes

require 'imputeMissingFeature'

--------------------------------------------------------------------------------
-- MAIN STARTS HERE
-------------------------------------------------------------------------------

-- Don't do the usually setup here. Instead all the setup tasks are done
-- in imputeMissingFeature. This approach reduces code duplication

torch.manualSeed(123)   -- set for reproducability


-- set the hyperparameters
local hp = {}
hp.mPerYear = {100, 300, 1000, 3000, 10000}
hp.k = {10, 30, 100}  -- the k value leads to the bandwidth
hp.lambda = {.001, .003, .01, .03, .1, .3, 1}
-- using only a few HPs, see where we are, and explore the rest
hp.mPerYear = {100, 300, 1000}
hp.k = {10, 30, 100}
hp.lambda = {.001, .003, .01}

-- TODO: use the random hyperparametes which are in OUTPUT/imputeRandomHyperparameters.csv
-- in the mean time, we are focused on determining the timing for one set of hyperparameters
-- so reduce to just one set

hp.mPerYear = {100}
hp.k = {60}
hp.lambda = {.001}

-- control number of input records read
-- set to -1 for all
local readLimit = 1000
readLimit = -1   -- read all the data

checkGradient = false
          
-- impute the missing feature and time how long that takes
local timer = Timer()
local recordsProcessed = imputeMissingFeature(
arg,
readLimit,
'HEATING.CODE',
'HEATING-CODE',
hp,
checkGradient
)

local wallClockSeconds = timer:wallclock()
local wallClockHours = wallClockSeconds / (60 * 60)
print(string.format('%d wall clock hours for %d input records', wallClockHours, recordsProcessed)

if readLimit ~= -1 then
   print('DISCARD RESULT. ALL INPUT NOT READ')
end

print('ok parcels-imputed-HEATING-CODE')


