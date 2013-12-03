-- main program to estiamte generalization error for imputing a missing variable
-- DESIGN CONSTRAINT: One executing instance of this program has access to the
-- file system.
-- 
-- INPUT FILES
-- OUTPUT/parcels-sfr-geocoding.csv
--   all of the single famile residential parcels with geocodes
-- 
-- OUTPUT FILES
-- All output and input-output files are written to a directory
-- formed by concatenating the program name with the important
-- parameters supplied on the command line.
--
-- The output files are these:
-- output.txt           The error rate.
-- cache.ser            Intermediate results. Also an input file.
-- log.txt              The log file.
-- confusionMatrix.ser  The final confusion matrix, serialized.
-- confusionMatrix.txt  The final confusion matrix, in txt form.
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
-- --set INTEGER      optional; if supplied number of hyperparameter set
--                    in file imputeRandomHyperparmaters.csv
--                    The file is used to set k, mPerYear, lambda

require 'assertEq'
require 'attributesLocationsTargetsApns'
require 'CommandLine'
require 'ConfusionMatrix'
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
require 'profiler'
require 'splitString'
require 'standardize'
require 'startLogging'  
require 'TableCached'
require 'torch'
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
   local functionName = 'getWeights'
   local vp, verboseLevel = makeVp(0, functionName)
   local verbose = verboseLevel > 0  
   local reportTiming =
      global.reportTiming.imputed_VAR_estGenError_HPS.getWeights 
   local timer = Timer(functionName, io.stderr)

   if verbose then
      vp(1, 
         'trainingLocation head', head(trainingLocations),
         'queryLocation', queryLocation,
         'hp', hp,
         'names', names,
         'reportTiming', reportTiming)
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
   timer:lap('setup')
   local dsNames = {latitude=cLatitude; longitude=cLongitude; year=cYear} -- rework for API
   local distances = distancesSurface(queryLocation,
                                      trainingLocations,
                                      hp.mPerYear,
                                      dsNames)
   if verbose then
      vp(3, 'distances head', head(distances))
   end

   -- determine weights using distances
   timer:lap('detemine distances')
   local weights1D = kernelEpanechnikovQuadraticKnn(distances, k)
   local weights1D = weights1D / torch.sum(weights1D)  -- weights sum to 1.0

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
                                
   if verbose then
      vp(1, 'weights size', weights:size())
      vp(1, 'weights head', head(weights))
   end

   timer:lap('determine weights')
   if reportTiming then
      timer:write()      
   end

   return weights
end

-- get the prediction for the i-th observation
-- use cached values where known
-- otherwise build up the cache and write it periodically
-- RETURN prediction, actual, cpuSecs, wallclockSecs
local function getPredictionActual(i, tableCached, train, val, stdTrainAttributes, hp, useCache, checkGradient, mean, std)
   local functionName = 'getPredictionActual'
   local vp, verboseLevel = makeVp(0, functionName)
   local timer
   if reportTiming then
      timer = Timer(functionName, io.stderr)
   end
   vp(1, 'i', i)
   local predictionActual = tableCached:fetch(i)
   vp(2, 'from tableCached: predictionActual', predictionActual)
   local prediction, actual
   local useCache = false
   if not useCache then
      vp(0, 'cache is turned off')
   end
   if useCache and predictionActual ~= nil then
      local prediction = predictionActual[1]
      local actual = predictionActual[2]
      if reportTiming then 
         local cpu, wallclock  = timer:cpu()
         vp(2, 'from cache; prediction', prediction, 'actual', actual, 'cpu', cpu)
      end
      return prediction, actual, cpu, wallclock 
   end

   -- compute values from scratch
   if global.profilerFilename then
      profiler.start(global.profilerFilename) -- turn on profiling
   end

   if reportTiming then 
      timer:lap('setup')
   end

   local weights = getWeights(
   train.locations.t,
   val.locations.t[i],
   hp,
   train.locations.names
   )

   if reportTiming then 
      timer:lap('getWeights')
   end

   local newX = val.attributes.t:narrow(1, i, 1) -- row i as 1 x n Tensor
   prediction = localLogRegNn(
   stdTrainAttributes,
   train.targets.t,
   weights,
   standardize(newX, mean, std),
   hp.lambda,
   checkGradient
   )
   
   if reportTiming then 
      time:lap('localLogRegNn')
      timer:write()
   end

   if global.profilerFilename then
      profiler.stop()
   end
   stop()

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
   --if i == 1 then stop() end 
   return prediction, actual, cpu, wallclock
end

-- validation error on model trained with training data using specified
-- hyperparameters
-- ARGS
-- train:          : table with NamedMatrix elements attributes, locations, apns, targets
-- val             : table with NamedMatrix elements attributes, locations, apns, targets
-- hp              : table of hyperparameters
-- checkGradient   : boolean
-- cachePath       : string, path to the prediction cache
-- setNumber       : optional, set number for hyperparameters
-- RETURN
-- confusion       : ConfusionMatrix
local function validationError(train,
                               val,
                               hp,
                               checkGradient,
                               cachePath,
                               setNumber)
   local vp, verboseLevel = makeVp(2, 'validationError')
   local debugging = verboseLevel > 0  -- true if debugging
   local investigateTiming = true
   local reportTiming = 
      global.reportTiming.imputed_VAR_estGenError_HPS.validationError
   vp(1, '*************************')
   if debugging then
      vp(1, 
         'train', train,
         'val', val,
         'hp', hp,
         'checkGradient', checkGradient,
         'cachePath', cachePath,
         'setNumber', setNumber)
   end

   -- validate args
   validateAttributes(train, 'table')
   validateAttributes(val, 'table')
   validateAttributes(hp, 'table')
   validateAttributes(checkGradient, 'boolean')
   validateAttributes(cachePath, 'string')
   validateAttributes(setNumber, {'nil', 'number'})
   if setNumber == nil then 
      setNumber = 0
   end
   
   -- setup cache to simulate checkpoint-restart
   -- read any cached values from disk file
   --   key   = i, the index
   --   value = sequence {prediction, actual}
   local tableCached = TableCached(cachePath, 'ascii')
   tableCached:replaceWithFile()

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


   -- create an estimate for each validation observation
   local confusionMatrix = ConfusionMatrix()
   for i = 1, nValObservations do
      local timer = Timer()
      local prediction, actual, cpuSecs, wallclockSecs = 
         getPredictionActual(i, tableCached, train, val, stdTrainAttributes, hp, useCache, checkGradient, mean, std)
      local cpu, wallclock = timer:cpuWallclock()
      vp(1, string.format('%d of %d prediction %d actual %d cpu %7.4f wallclock %7.4f k %d mPerYear %f lambda %f set %d',
                          i, nValObservations, prediction, actual, cpuSecs, wallclockSecs, hp.k, hp.mPerYear, hp.lambda, setNumber))
      --stop()
      confusionMatrix:add(actual, prediction)

      -- print periodically
      local printFrequency = 100
      if i % printFrequency == 0 then
         print('current error rate = ' .. tostring(confusionMatrix:errorRate()))
         confusionMatrix:printTo(io.stdout, 'current confusion matrix')
      end

      -- collect garbage periodically
      local cgFrequency = 100
      if i % cgFrequency == 0 then
         local used = memoryUsed() -- also does garbage collection
         vp(1, 'memory used after gc', used)
      end

   end
   
   tableCached:writeToFile()

   if verboseLevel > 0 then
      confusionMatrix:printTo(io.stdout, 'final confusion matrix')
   end

   return confusionMatrix
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

-- return k, lambda, mPerYear values from file
local function getHyperparameters(setNumber, outputDir)
   local vp = makeVp(2, 'getHyperparameters')
   vp(1, 'setNumber', setNumber, 'outputDir', outputDir)

   local filename = 'imputeRandomHyperparameters.csv'
   local outputPath = outputDir .. '/' .. filename
   vp(2, 'outputPath', outputPath)

   local nm = NamedMatrix.readCsv{file=outputPath,numberColumns={'set', 'k', 'mPerYear', 'lambda'}}
   vp(2, 'nm', nm)
   
   validateAttributes(setNumber, 'number', '<=', nm.t:size(1))
   local k = nm:get(setNumber, 'k')
   local lambda = nm:get(setNumber, 'lambda')
   local mPerYear = nm:get(setNumber, 'mPerYear')

   vp(1, 'k', k, 'lambda', lambda, 'mPerYear', mPerYear)
   return k, lambda, mPerYear
end
   



-------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------


local vp = makeVp(2, 'imputed-VAR-estGenError-HPS')
vp(2, 'clargs', arg) 

-- set global parameters (usually not a good programming practice)
global = {}
global.reportTiming = {}
global.reportTiming.localLogRegNn = {}
global.reportTiming.localLogRegNn.fitModel = false
global.reportTiming.localLogRegNn.localLogRegNn = false
global.reportTiming.localLogRegNn.lossGrad = false
global.reportTiming.localLogRegNn.opfunc = false
global.reportTiming.sgdBottou = false
global.reportTiming.sgdBottouDriver = false
global.reportTiming.imputed_VAR_estGenError_HPS = {}
global.reportTiming.imputed_VAR_estGenError_HPS.validationError = true
global.reportTiming.imputed_VAR_estGenError_HPS.getWeights = true
global.reportTiming.imputed_VAR_estGenError_HPS.getPredictionActual = true

-- set to nil to turn off profiling
global.profilerFilename = '/tmp/luaprofiler.txt' -- ref luaprofile.lurforge.net/manual.html
global.profilerFilename = nil  -- turn off profiler

-- parse command line
local args = {}
do 
   local cl = CommandLine(arg)
   args.output = cl:required('--output')
   args.readlimit = tonumber(cl:defaultable('--readlimit', '-1'))
   args.var = cl:required('--var')

   -- either --set is supplied or --mPerYear, --k, --lambda are supplied
   args.set = cl:maybeValue('--set')
   vp(2, 'args', args) 
   if args.set then
      args.set = tonumber(args.set)
      args.k, args.lambda, args.mPerYear = getHyperparameters(args.set, args.output)
   else
      args.mPerYear = tonumber(cl:required('--mPerYear'))
      args.k = tonumber(cl:required('--k'))
      args.lambda = tonumber(cl:required('--lambda'))
   end
end
vp(2, 'args', args)
local programName = arg[0]  -- now no longer dependent on special var arg

-- validate command line parameters
validateAttributes(args.mPerYear, 'number', 'positive')
validateAttributes(args.k, 'number' ,'integer', '>', 1)
validateAttributes(args.readlimit, 'number', '>=', -1)

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
local confusionMatrixSerPath = outputDir .. '/' .. 'confusionMatrix.ser'
local confusionMatrixTxtPath = outputDir .. '/' .. 'confusionMatrix.txt'

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
print(' outputPath             : ' .. outputPath)
print(' inputPath              : ' .. inputPath)
print(' cachePath              : ' .. cachePath)
print(' logPath                : ' .. logPath)
print(' confusionMatrixSerPath : ' .. confusionMatrixSerPath)
print(' confusionMatrixTxtPath : ' .. confusionMatrixTxtPath)

if args.readlimit ~= -1 then
   print('DISCARD OUTPUT; NOT ALL INPUT WILL BE READ')
end

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
local confusionMatrix = validationError(train, val, hp, checkGradient, cachePath, args.set)
confusionMatrix:printTo(io.stdout, 'final confusion matrix')

-- write the validation error to the output file
do 
   local output, err = io.open(outputPath, 'w')
   assert(output, err)
   output:write(tostring(confusionMatrix:errorRate()) .. '\n')
   output:close()
end

-- write the confusion matrix
do
   local confusionTxt, err = io.open(confusionMatrixTxtPath, 'w')
   assert(confusionTxt, err)
   confusionMatrix:printTo(confusionTxt, 'final confusion matrix')
   confusionTxt:close()

   torch.save(confusionMatrixSerPath, confusionMatrix, 'ascii')
end

print('finished')
