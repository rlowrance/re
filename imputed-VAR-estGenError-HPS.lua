-- main program to estiamte generalization error for imputing a missing variable
-- DESIGN CONSTRAINT: One executing instance of this program has access to the
-- file system.
-- 
-- INPUT FILES
-- OUTPUT/parcels-sfr-geocoding.csv
--   all of the single famile residential parcels with geocodes
-- 
-- OUTPUT FILES
-- OUTPUT/imputed-VAR/estGenError-HPS.txt
--   contains a number in ascii, the estimated generalization error
--   for the variable VAR using hyperparameters HPS
--   HPS is in this format
--     mPerYear-NUMBER-k-NUMBER-lambda-NUMBER
--   NOTE: THE OUTPUT DIRECTORY MUST EXIST BEFORE RUNNING THIS PROGRAM
--
-- INPUT-OUTPUT FILE
-- OUTPUT/imputed-VAR/estGenError-HPS[-readlimit-NUMBER]-cache.csv
--   Contains cached values for the predicted value of VAR for each i
--   This cache is used to implement a checkpoint-restart capability.
--
-- COMMAND LINE PARAMETERS
-- --output STRING    Path to output directory in the file system
-- --var VAR          Name of variable in the csv file to impute
-- --mPerYear NUMBER  Number of meters in one year
--                    Used by distance function
-- --k INTEGER        Number of neighbors to consider in the kernel
-- --lambda NUMBER    Importance of the L2 Regularizer in the local logistic regression
-- --readlimit NUMBER optional; default -1
--                    If >= 0, number of input records to read
--                    Use for testing

require 'assertEq'
require 'attributesLocationsTargetsApns'
require 'CommandLine'
require 'directoryAssureExists'
require 'distancesSurface'
require 'fileAssureExists'
require 'fileDelete'
require 'head'
require 'ifelse'
require 'kernelEpanechnikovQuadraticKnn'
require 'localLogRegNn'
require 'makeVp'
require 'NamedMatrix'
require 'parseCommandLine'
require 'splitString'
require 'standardize'
require 'startLogging'  
require 'TableCached'
require 'validateAttributes'

-------------------------------------------------------------
-- LOCAL FUNCTIONS
-- ----------------------------------------------------------

-- return weight to be used for each training location, 
-- given the prediction location
-- use the Epanechnikov quadratic kernel and k-nearest neighbors
-- ARGS
-- trainingLocations  : 2D Tensor of size n x 3
-- queryLocation      : 1D Tensor of size 3
-- hp                 : table of hyperparameters specifically mPerYear and k
-- names              : sequence of 3 names of columns in both locations
-- RETURN
-- weights : Tensor size n x 1, kernel-weighted average (column vector) summing to 1
local function getWeights(trainingLocations,
                          queryLocation,
                          hp,
                          names)
   local vp, verbose = makeVp(0, 'getWeights')
   local debugging = verbose > 0  

   local timerAll = Timer()

   if debugging then
      vp(1, 
         'trainingLocation head', head(trainingLocations),
         'queryLocation', queryLocation,
         'hp', hp,
         'names', names)
   end

   -- validate args
   local n = trainingLocations:size(1)
   validateAttributes(trainingLocations, 'Tensor', 'size', {n,3})
   validateAttributes(queryLocation, 'Tensor', 'size', {3})
   validateAttributes(hp, 'table')
   validateAttributes(names, 'table', 'size', 3)

   local mPerYear = hp.mPerYear
   local k = hp.k

   validateAttributes(mPerYear, 'number', '>', 0)
   validateAttributes(k, 'number', '>', 1)

   -- provide names for columns and check that they are correct
   local cLatitude = 1
   local cLongitude = 2
   local cYear = 3

   assert(names[cLatitude] == 'G LATITUDE')
   assert(names[cLongitude] == 'G LONGITUDE')
   assert(names[cYear] == 'YEAR.BUILT')
   
   -- check if value is in cache
   -- how to structure the cache is far from clear

   -- determine distance from queryLocation to each trainingLocation
   local timerDistances = Timer()
   local dsNames = {latitude=cLatitude; longitude=cLongitude; year=cYear} -- rework for API
   local distances = distancesSurface(queryLocation,
                                      trainingLocations,
                                      hp.mPerYear,
                                      dsNames)
   local cpuDistances = timerDistances:cpu()
   if debugging then
      vp(3, 'distances head', head(distances))
   end

   -- determine weights using distances
   local timerWeights = Timer()
   local weights1D = kernelEpanechnikovQuadraticKnn(distances, k)
   local weights1D = weights1D / torch.sum(weights1D)  -- weights sum to 1.0
   local cpuWeights = timerWeights:cpu()

   -- view weights as 2D
   local weights = torch.Tensor(weights1D:storage(),
                                1,     -- offset
                                n, 1,  -- size 1, stride 1
                                1, 1)  -- size 2, stride 2

   -- check that view works
   if false then
      for i = 1, n do
         assert(weights1D[i] == weights[i][1], 'failed for i = ' .. tostring(i))
      end
      vp(0, 'remove checking code')
      stop()
   end
                                
   if debugging then
      vp(1, 'weights size', weights:size())
      vp(1, 'weights head', head(weights))
      local cpuOverall = timerAll:cpu()
      vp(2, 
         'cpu time: overall', cpuOverall,
         'cpu time: determine distances', cpuDistances,
         'cpu time: determine weights', cpuWeights,
         'cpu time: other', cpuOverall - cpuDistances - cpuWeights
         )
   end

   return weights
end

-- validation error on model trained with training data using specified
-- hyperparameters
-- ARGS
-- train:          : table with NamedMatrix elements attributes, locations, apns, targets
-- val             : table with NamedMatrix elements attributes, locations, apns, targets
-- hp              : table of hyperparameters
-- checkGradient   : boolean
-- cachePath       : string, path to the prediction cache
-- RETURN
-- errorRate       : number, fraction of errors on re-estimated validation
--                   targets
local function validationError(train,
                               val,
                               hp,
                               checkGradient,
                               cachePath)
   local vp, verboseLevel = makeVp(2, 'validationError')
   local debugging = verboseLevel > 0  -- true if debugging
   local investigateTiming = true
   local reportTiming = true
   vp(1, '*************************')
   if debugging then
      vp(1, 
         'train', train,
         'val', val,
         'hp', hp,
         'checkGradient', checkGradient,
         'cachePath', cachePath)
   end

   -- validate args
   validateAttributes(train, 'table')
   validateAttributes(val, 'table')
   validateAttributes(hp, 'table')
   validateAttributes(checkGradient, 'boolean')
   validateAttributes(cachePath, 'string')

   -- setup cache to simulate checkpoint-restart
   -- read any cached values from disk file
   --   key   = i, the index
   --   value = sequence {prediction, actual}
   local tableCached = TableCached(cachePath, 'ascii')
   if not investigateTiming then 
      tableCached:replaceWithFile()
   end

   if false then -- debugging code
      vp(2, 'existing cache entries')
      for k, v in tableCached:pairs() do
         vp(2, 'k', k, 'v', v)
      end
   end

   -- standardize the attributes
   local stdTrainAttributes, mean, std = standardize(train.attributes.t)
   local stdValAttributes = standardize(val.attributes.t, mean, std)

   -- count number of errors (0/1 loss) on the validation set
   local nValObservations = val.attributes.t:size(1)
   vp(1, 'nValObservations', nValObservations)
   local m = train.attributes.t:size(1)
   vp(1, 'number of training observations m', m)
   local nErrors = 0

   -- get the prediction for the i-th observation
   -- use cached values where known
   -- otherwise build up the cache and write it periodically
   -- RETURN prediction, actual, cpuSecs, wallclockSecs
   local function getPredictionActual(i)
      local timer = Timer()
      local vp = makeVp(0, 'getPredictionActual')
      vp(1, 'i', i)
      local predictionActual = tableCached:fetch(i)
      vp(2, 'from tableCached: predictionActual', predictionActual)
      local prediction, actual
      if predictionActual ~= nil then
         local prediction = predictionActual[1]
         local actual = predictionActual[2]
         local cpu, wallclock  = timer:cpuWallclock()
         vp(2, 'from cache; prediction', prediction, 'actual', actual, 'cpu', cpu, 'wallclock', wallclock)
         return prediction, actual, cpu, wallclock 
      end

      -- compute values from scratch
      local timerWeights = Timer()
      local weights = getWeights(train.locations.t,
                                 val.locations.t[i],
                                 hp,
                                 train.locations.names)
      local weightCpu = timerWeights:cpu()

      local timerLlr = Timer()
      local newX = val.attributes.t:narrow(1, i, 1) -- row i as 1 x n Tensor
      prediction = localLogRegNn(stdTrainAttributes,
                                 train.targets.t,
                                 weights,
                                 standardize(newX, mean, std),
                                 hp.lambda,
                                 checkGradient)
      local llrCpu = timerLlr:cpu()
      if reportTiming then
         vp(0, 'i', i, 'weightCpu', weightCpu, 'llrCpu', llrCpu)
      end

      actual = val.targets.t[i][1]

      tableCached:store(i, {prediction, actual})
      local cacheWriteFrequency = 1 -- for testing
      if i % cacheWriteFrequency == 0 then
         vp(1, 'writing predictions to ' .. cachePath)
         tableCached:writeToFile()
      end
      
      local cpu, wallclock = timer:cpuWallclock()
      if cpu > wallclock and false then
         print(string.format('warning: cpu secs (%f) > wallclock sec(%f)', cpu, wallclock))
      end
      vp(1, 'prediction', prediction, 'actual', actual, 'cpu', cpu, 'wallclock', wallclock)
      if i == 1 then stop() end 
      return prediction, actual, cpu, wallclock
   end

   -- create an estimate for each validation observation
   for i = 1, nValObservations do
      local prediction, actual, cpuSecs, wallclockSecs = getPredictionActual(i)
      vp(1, string.format('%d of %d prediction %d actual %d cpu %7.4f wallclock %7.4f',
                          i, nValObservations, prediction, actual, cpuSecs, wallclockSecs))
      --stop()
      if prediction ~= actual then
         nErrors = nErrors + 1
      end

      -- collect garbage periodically
      local cgFrequency = 100
      if i % cgFrequency == 0 then
         local used = memoryUsed() -- also does garbage collection
         vp(1, 'memory used after gc', used)
      end

   end

   local errorRate = nErrors / nValObservations
   vp(1, 'errorRate', errorRate)
   stop()
   return errorRate
end

-- split randomly into [train|val|test].{Attributes,Locations,Targets,Apns}
-- ARGS:
-- nm       : NamedMatrix
-- fTrain  : number, >= 0 , <= 1, fraction of observations to training set
-- fVal    : number, >= 0 , <= 1, fraction of observations to validation set
-- RETURNS:
-- train   : NamedMatrix
-- val     : NamedMatrix
-- test    : NamedMatri
function split(nm, fTrain, fValidate)
   validateAttributes(nm, 'NamedMatrix')
   validateAttributes(fTrain, 'number', '>=', 0, '<=', 1)
   validateAttributes(fValidate, 'number', '>=', 0, '<=', 1)
   assert(fTrain + fValidate <= 1)

   local function isTrain(rowIndex)
      return torch.uniform(0,1) <= fTrain
   end

   local train, rest = nm:splitRows(isTrain)
   
   -- randomly split rest into validation and test
   local validationFraction = fValidate / (1 - fTrain)
   
   local function isValidation(rowIndex)
      return torch.uniform(0,1) <= validationFraction
   end
   
   local val, test = rest:splitRows(isValidation)

   return train, val, test
end

local function splitParse(labeled, fTrain, fValidate, targetFeatureName)
   validateAttributes(labeled, 'NamedMatrix')
   validateAttributes(fTrain, 'number', '>=', 0, '<=', 1)
   validateAttributes(fValidate, 'number', '>=', 0, '<=', 1)
   validateAttributes(targetFeatureName, 'string')

   local train, val, test = split(labeled, fTrain, fValidate)
   
   local trainParsed = attributesLocationsTargetsApns(train, targetFeatureName)
   local valParsed = attributesLocationsTargetsApns(val, targetFeatureName)
   local testParsed = attributesLocationsTargetsApns(test, targetFeatureName)

   return trainParsed, valParsed, testParsed
end


-- split into observations with known targets and unknown targets
-- ARGS
-- data              : NamedMatrix
-- targetFeatureName : string
-- RETURNS 2 NamedMatrices
-- known   : contains all observations with target feature is known
-- unknown : contains all observations with target feature NaN
local function separate(data, targetFeatureName)
   local vp = makeVp(0, 'separate')
   vp(1, '\ndata', data, 'targetFeatureName', targetFeatureName)
   assert(torch.typename(data) == 'NamedMatrix')
   assert(type(targetFeatureName) == 'string')
   
   local targetFeatureColIndex = data:columnIndex(targetFeatureName)
   
   local function hasFeature(rowIndex)
      return not isnan(data.t[rowIndex][targetFeatureColIndex])
   end

   local knownTarget, unknownTarget = data:splitRows(hasFeature)
   vp(1, 'knownTarget', knownTarget, 'unknownTarget', unknownTarget)
   return knownTarget, unknownTarget
end 

-- read the input file containing parcels
-- ARGS
-- pathToParcels     : string, location of input file
-- readLimit         : number, possible limit on number of records to read
-- targetFeatureName : string, column name for target feature
-- RETURNS
-- data              : NamedMatrix
local function readParcels(pathToParcels, readLimit, targetFeatureName)
   local vp = makeVp(0, 'readParcels')
   vp(1, 
      'pathToParcels', pathToParcels, 
      'readLimit', readLimit,
      'targetFeatureName', targetFeatureName)
   validateAttributes(pathToParcels, 'string')
   validateAttributes(readLimit, 'number')
   validateAttributes(targetFeatureName, 'string')

   local numberColumns = 
   {-- description
   'LAND.SQUARE.FOOTAGE', 'TOTAL.BATHS.CALCULATED',
   'BEDROOMS', 
   'PARKING.SPACES', 'UNIVERSAL.BUILDING.SQUARE.FEET',
   -- location
   'YEAR.BUILT', 'G LATITUDE', 'G LONGITUDE',
   -- identification
   'apn.recoded'
   }

   local factorColumns = {targetFeatureName}

   local timer = Timer()
   local parcels = NamedMatrix.readCsv
   {file=pathToParcels
   ,nRows=readLimit
   ,numberColumns=numberColumns
   ,factorColumns=factorColumns
   ,nanString=''
   }

   vp(0, 'wall clock secs to read parcels file', timer:wallclock())
   return parcels
end

-- read the parcels and split them into labeled and unlabeled
local function createLabeledUnlabeled(pathToParcels, readLimit, targetFeatureName)
   local data = readParcels(pathToParcels, readLimit, targetFeatureName)
   local labeled, unlabeled = separate(data, targetFeatureName)
   return labeled, unlabeled
end

-- read the parcels and split them into labeled and unlabeled
local function createLabeledUnlabeled(pathToParcels, readLimit, targetFeatureName)
   local data = readParcels(pathToParcels, readLimit, targetFeatureName)
   local labeled, unlabeled = separate(data, targetFeatureName)
   return labeled, unlabeled
end

-------------------------------------------------------------
-- MAIN PROGRAM
-- ---------------------------------------------------------

local vp = makeVp(2, 'imputed-VAR-estGenError-HPS')
vp(2, 'clargs', arg) 

-- parse command line
local args = {}
do 
   local cl = CommandLine(arg)
   args.output = cl:required('--output')
   args.var = cl:required('--var')
   args.mPerYear = tonumber(cl:required('--mPerYear'))
   args.k = tonumber(cl:required('--k'))
   args.lambda = tonumber(cl:required('--lambda'))
   args.readlimit = tonumber(cl:defaultable('--readlimit', '-1'))
end
vp(2, 'args', args)
local programName = arg[0]  -- now no longer dependent on special var arg

-- validate command line parameters
validateAttributes(args.mPerYear, 'number', 'positive')
validateAttributes(args.k, 'number' ,'integer', '>', 1)
validateAttributes(args.readlimit, 'number', '>=', -1)

if readlimit ~= -1 then
   print('DID NOT READ ENTIRE INPUT FILE; DISCARD OUTPUT')
end

-- set random number seed
torch.manualSeed(123)

-- setup file paths
local importantParameters =  -- all but the location of the output directory
   tostring(args.var) .. '-' ..
   tostring(args.mPerYear) .. '-' ..
   tostring(args.k) .. '-' ..
   tostring(args.lambda) .. '-' ..
   tostring(args.readlimit) 
local outputDir  = args.output ..'/' .. programName .. '-' .. importantParameters
vp(2, 'outputDir', outputDir)
directoryAssureExists(outputDir)

local outputPath = outputDir .. '/' ..  'output.txt'
local cachePath = outputDir .. '/' .. 'cache.ser'
local logPath = outputDir .. '/' .. 'log.txt'

-- verify that we can write the output file
fileAssureExists(outputPath)
fileDelete(outputPath)  -- program always creates a new output file

local inputFile = 'parcels-sfr-geocoded.csv'
local inputPath = args.output .. '/' .. inputFile

-- start logging so that print() writes to stdout and the log file
startLogging(logPath, arg)

-- log command line parameters
print('command line parameters')
print(' --output    : ' .. args.output)
print(' --var       : ' .. args.var)
print(' --mPerYear  : ' .. args.mPerYear)
print(' --k         : ' .. args.k)
print(' --lambda    : ' .. args.lambda)
print(' --readlimit : ' .. args.readlimit)

-- log input/output paths
print('file paths')
print(' outputPath : ' .. outputPath)
print(' inputPath  : ' .. inputPath)
print(' cachePath  : ' .. cachePath)
print(' logPath    : ' .. logPath)

-- read parcels, split into labeled and unlabeled

print('reading input')
local labeled, unlabeled = createLabeledUnlabeled(inputPath, args.readlimit, args.var)
vp(0, 'number labeled observations', labeled.t:size(1))
vp(0, 'number unlabeled observations', unlabeled.t:size(1))
 
-- split labeled into test, val, train
local fTrain = .60
local fValidate = .20
local train, val, test = splitParse(labeled, fTrain, fValidate, args.var) -- creates NamedMatrices

-- determine error on validation set
local hp = {mPerYear = args.mPerYear, k=args.k, lambda=args.lambda}
local checkGradient = false
local valError = validationError(train, val, hp, checkGradient, cachePath)

stop('do more') -- like write the output file
