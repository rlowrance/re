-- main program to estiamte generalization error for imputing a missing variable
-- INPUT FILES
-- OUTPUT/parcels-sfr-geocoding.csv
--   all of the single famile residential parcels with geocodes
-- 
-- OUTPUT FILES
-- OUTPUT/imputed-VAR/estGenError-HPS.txt
--   contains a number in ascii, the estimated generalization error
--   for the variable VAR using hyperparameters HPS
--   NOTE: THE OUTPUT DIRECTORY MUST EXIST BEFORE RUNNING THIS PROGRAM
--
-- COMMAND LINE PARAMETERS
-- --output STRING    Path to output directory in the file system
-- --var VAR          Name of variable in the csv file to impute
-- --mPerYear NUMBER  Number of meters in one year
--                    Used by distance function
-- --k INTEGER        Number of neighbors to consider in the kernel
-- --lambda NUMBER    Importance of the L2 Regularizer in the local logistic regression

require 'makeVp'
require 'parseCommandLine'
require 'startLogging'  
require 'validateAttributes'

-------------------------------------------------------------
-- LOCAL FUNCTIONS
-- ----------------------------------------------------------

-------------------------------------------------------------
-- MAIN PROGRAM
-- ---------------------------------------------------------

local vp = makeVp(2, 'imputed-VAR-estGenError-HPS')
vp(2, 'clargs', arg) 

-- parse command line
local function getRequiredValue(keyWord)
   local vp = makeVp(1, 'getRequiredValue')
   vp(1, 'arg', arg, 'keyWord', keyWord)
   local string = parseCommandLine(arg, 'value', keyWord)
   assert(string ~= nil, keyWord .. ' is missing')
   return string
end

local output = getRequiredValue('--output')

local var = getRequiredValue('--var')

local mPerYear = tonumber(getRequiredValue('--mPerYear'))
validateAttributes(mPerYear, 'number', 'positive')

local k = tonumber(getRequiredValue('--k'))
validateAttributes(k, 'number' ,'integer', '>', 1)

local lambda = tonumber(getRequiredValue('--lambda'))
validateAttributes(lambda, 'number', 'nonnegative')

-- set random number seed
torch.manualSeed(123)

-- setup file paths
local outputDir  = output ..'/' .. 'imputed-' .. var .. '/' 
local outputFileBase = 'estGenError-' .. tostring(mPerYear) .. '-' .. tostring(k) .. '-' .. tostring(lambda) 
local outputFile = outputFileBase .. '.txt'
local outputPath = outputDir .. outputFile

-- verify that we can write the output file
local f, err = io.open(outputPath, 'w') -- make sure output can be eventually written
if f == nil then
   assert(f, err .. '; maybe you need to create the directory')
end
f:close()

local inputFile = 'parcels-sfr-geocoded.csv'
local inputPath = output .. '/' .. inputFile

local logPath = outputDir .. outputFileBase .. '.log'

-- start logging so that print() writes to stdout and the log file
startLogging(logPath, arg)
print('outputPath: ' .. outputPath)
print('inputPath: ' .. inputPath)

stop('do more')
