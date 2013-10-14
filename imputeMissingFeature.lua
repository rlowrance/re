-- global function imputeMissingFeature
--
-- create new file containing a single missing feature
--
-- ARGS:
-- clArgs            : table of command line arguments (not used but printed)
-- readLimit         : number, limit on number of input records to read
-- targetFeatureName : string, field name in the input field\
-- outputFileSuffix  : string
--                     write file OUTPUT/parcels-imputed-<outputFileSuffix>.csv
-- hp                : table of hyperpameters to test
--                     hp.mPerYear : sequence
--                     hp.k        : sequence
--                     hp,lambda   : sequence
-- checkGradient     : boolean
-- RESULTS: none





require 'assertEq'
require 'attributesLocationsTargetsApns'
require 'bestApns'
require 'CacheFile'
require 'distancesSurface'
require 'equalTensors'
require 'standardize'
require 'ifelse'
require 'isnan'
require 'hasNA'
require 'hasNaN'
require 'kernelEpanechnikovQuadraticKnn'
require 'localLogReg'
require 'localLogRegNn'
require 'makeVp'
require 'maybeLoad'
require 'memoryUsed'
require 'memoizedComputationOnDisk'
require 'modelLogreg'
require 'NamedMatrix'
require 'splitString'
require 'startLogging'
require 'sweep2'
require 'unique'
require 'validateAttributes'

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------


-- return weight to be used for each training location, 
-- given the prediction location
-- use the Epanechnikov quadratic kernel and k-nearest neighbors
-- ARGS
-- trainingLocations  : 2D Tensor of size n x 3
-- queryLocation      : 1D Tensor of size 3
-- hp                 : table of hyperparameters including mPerYear and k
-- names              : sequence of 3 names of columns in both locations
-- RETURN
-- weights : Tensor size n x 1, kernel-weighted average (column vector) summing to 1
local function getWeights(trainingLocations,
                          queryLocation,
                          hp,
                          names)
   local vp, verbose = makeVp(1, 'getWeights')
   local d = verbose > 0

   if d then
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
   local timer = Timer()
   local distances = distancesSurface(queryLocation,
                                      trainingLocations,
                                      hp.mPerYear,
                                      names)
   vp(0, 'cpu sec distancesSurface', timer:cpu())
   vp(2, 'distances head', head(distances))

   -- determine weights using distances
   local timer = Timer()
   local weights1D = kernelEpanechnikovQuadraticKnn(distances, k)
   local weights1D = weights1D / torch.sum(weights1D)  -- weights sum to 1.0
   vp(0, 'cpu sec kernel', timer:cpu())

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
                                
   vp(1, 'weights size', weights:size())
   vp(1, 'weights head', head(weights))
   return weights
end


-- validation error on model trained with training data using specified
-- hyperparameters
-- ARGS
-- train:          : table with NamedMatrix elements attributes, locations, targets
-- val             : table with NamedMatrix elements attributes, locations, targets
-- hp              : table of hyperparameters
-- checkGradient   : boolean
-- neighborsAccess : function(apn) --> 1D tensor of 
-- RETURN
-- errorRate       : scalar, fraction of errors on re-estimated validation
--                   targets
local function validationError(train,
                               val,
                               hp,
                               checkGradient)
   local vp, verboseLevel = makeVp(1, 'validationError')
   local d = verboseLevel > 0
   vp(1, '*************************')
   if train then
      vp(1, 
         'train', train,
         'val', val,
         'hp', hp,
         'checkGradient', checkGradient)
   end

   -- validate args
   validateAttributes(train, 'table')
   validateAttributes(val, 'table')
   validateAttributes(hp, 'table')
   validateAttributes(checkGradient, 'boolean')

   -- standardize the attributes
   local stdTrainAttributes, mean, std = standardize(train.attributes.t)
   local stdValAttributes = standardize(val.attributes.t, mean, std)

   -- determine number of errors (0/1 loss) on the validation set
   local nValObservations = val.attributes.t:size(1)
   vp(1, 'nValObservations', nValObservations)
   local m = train.attributes.t:size(1)
   vp(1, 'm', m)
   local nErrors = 0
   vp(1, 'hp.lambda', hp.lambda)
   for i = 1, nValObservations do
      local timerOneObs = Timer()
      local queryAttributes = val.attributes[i]
      local queryLocation = val.locations[i]
      local timerGetWeights = Timer()
      local weights = getWeights(train.locations.t,
                                 val.locations.t[i],
                                 hp,
                                 train.locations.names)
      cpuGetWeights = timerGetWeights:cpu()
      assertEq(weights:sum(), 1.0, .00001)
      validateAttributes(weights, 'Tensor', 'size', {m,1})
      vp(0, 'getWeights cpu sec', cpuGetWeights)
    
      local newX = val.attributes.t:narrow(1, i, 1)  -- row i as 1 x n Tensor
      vp(2, 'trainTargets', trainTargets)
      -- use Neural Net version
      local timerLocalLogRegNn = Timer()
      local prediction = localLogRegNn(stdTrainAttributes,
                                       train.targets.t,
                                       weights,
                                       standardize(newX,
                                                   mean,
                                                   std),
                                       hp.lambda,
                                       checkGradient)
      local cpuLocalLogRegNn = timerLocalLogRegNn:cpu()
      
      local isError = prediction ~= val.targets.t[i][1]
      if isError then
         nErrors = nErrors + 1
      end
      -- need to collect garbage periodically  because of a bug in torch7
      local timerMemoryUsed = Timer()
      local used = memoryUsed()  -- collect garbage
      local cpuMemoryUsed = timerMemoryUsed:cpu()
      vp(1, string.format('i %d of %d prediction %d actual %d mem %f  %s',
                          i, nValObservations, prediction, val.targets.t[i][1],
                          used,
                          ifelse(isError, 'error', '')))
      vp(0, 'cpu seconds')
      vp(1, 
         '  get weights', cpuGetWeights, 
         '  local log reg', cpuLocalLogRegNn,
         '  garbage collection', cpuMemoryUsed)
      pressEnter()
      --if i == 1 then stop() end
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

-- parse a NamedMatrix into 
-- return best hyperparameters, the ones that minimize the un-regularized
-- validation error. Use simple validation
-- ARGS:
-- labeled           : NamedMatrix containing all the labeled data
--                     split into train, val, test (test is not used in this code)
-- hp                : table of hyperparameter values to examine, with 3 fields
--                     hp.mPerYear : sequence of meters per Year
--                     hp.ks       : sequence of k (number of neighbors)
--                     hp.lambda   : sequence of L2 regularizer weights
-- fTrain            : number, fraction of observations to training data
-- fValidate         : number, fraction of observations to validation data
-- cacheFilePath     : string, path to file holding previous hp tests
-- targetFeatureName : string, name of target feature
-- dirOutput         : string, path to directory holding output files
--                     in particular, file neighbors-indices-METERSPERYEAR.csv 
-- checkGradient     : boolean
-- RETURNS:
-- bestHp            : table of best hyperparameters
local function selectModel(labeled, 
                           hp, 
                           fTrain, 
                           fValidate, 
                           cacheFilePath, 
                           targetFeatureName,
                           dirOutput,
                           checkGradient)
   local vp = makeVp(2, 'selectModel')
   vp(1, '*************************')
   if false then vp(1, 
                    'labeled.t size', labeled.t:size(),
                    'labeled.names', labeled.names,
                    'hp', hp,
                    'fTrain', fTrain,
                    'fValidate', fValidate,
                    'cacheFilePath', cacheFilePath,
                    'targetFeatureName', targetFeatureName,
                    'dirOutput', dirOutput,
                    'checkGradient', checkGradient)
   end

   -- validate args
   validateAttributes(labeled, 'NamedMatrix')
   validateAttributes(hp, 'table')
   validateAttributes(fTrain, 'number', '>', 0)
   validateAttributes(fValidate, 'number', '>', 0)
   validateAttributes(cacheFilePath, 'string')
   validateAttributes(targetFeatureName, 'string')
   validateAttributes(dirOutput, 'string')
   validateAttributes(checkGradient, 'boolean')


   -- don't use cache for now
   local useCache = false

   -- split into train/val/test and parse out the components
   local cachePath = dirOutput .. 'imputeMissingFeature-' .. 'splitParse'
   local version = 1  -- version number for splitParse function
   local usedCache, train, val, test
   if useCache then 
      usedCache, train, val, test =
         memoizedComputationOnDisk(cachePath, version, splitParse, 
                                   labeled, fTrain, fValidate, targetFeatureName)
   else 
      usedCache = false 
      train, val, test = splitParse(labeled, fTrain, fValidate, targetFeatureName) 
   end
   vp(2, 'usedCache', usedCache)
   
   -- setup file cache that contains previous results
   local cache = CacheFile{keyNames={'mPerYear', 'k', 'lambda'},
                           valueNames={'estGenError'},
                           filePath=cacheFilePath}
   vp(0, 'cacheFilePath', cacheFilePath)
   cache:merge()  -- read in any cache key-value pairs stored on disk

   -- test each hyperparameter combination to determine combination with
   -- lowest un-regularized error on the validation set
   local bestHp = {}
   local lowestValError = math.huge
   for _, mPerYear in ipairs(hp.mPerYear) do
      for _, k in ipairs(hp.k) do
         for _, lambda in ipairs(hp.lambda) do
            local hp = {mPerYear=mPerYear, k=k, lambda=lambda}
            vp(1, 'hp', hp)
            local valError = cache:fetch{keys={mPerYear, k, lambda}}
            if valError == nil then
               fromCache = ''
               local timer = Timer()
               valError = validationError(train,
                                          val,
                                          hp,
                                          checkGradient)
               vp(0, 'validationError cpu sec', timer:cpu())
            else
               fromCache = 'from Cache'
               valError = valError[1]
            end
            vp(0, string.format('mPerYear %f k %d lambda %f valError %f %s',
                                mPerYear, k, lambda, valError, fromCache))

            -- save each new result, to facilitate restarts
            cache:store{keys={mPerYear, k, lambda},
                        values={valError}}
            cache:write()
            
            -- identify best set of hyperparameters
            if valError < lowestValError then
               lowestValError = valError
               bestHp = hp
               vp(0, 'new lowestValError', lowestValError)
               vp(0, 'new bestHp', bestHp)
            end

            -- print the cache file
            local nm = NamedMatrix.readCsv{file=cacheFilePath,
                                           numberColumns={'mPerYear',
                                                          'k',
                                                          'lambda',
                                                          'estGenError'}}
            vp(0, 'content of cache file ', cacheFilePath)
            for i = 1, nm.t:size(1) do
               vp(0,
                  string.format('i %d mPerYear %f k %d lambda %f ' ..
                                'estGenError %f',
                                i, 
                                nm.t[i][1], nm.t[i][2], nm.t[i][3], nm.t[i][4],
                                nm.t[i][5]))
            end
         end
      end
   end
   vp(0, 'bestHp', bestHp)
   vp(0, 'lowest validation error', lowestValError)
   stop()

   return bestHp
end

local function extractTensor(df)
   local colNames = df:columnNames()
   local result = df:asTensor(colNames)
   return result
   end

local function extract1DTensor(df)
   local result = extractTensor(df)
   assert(result:dim() == 1)
   return result
end

local function extract2DTensor(df)
   local result = extractTensor(df)
   assert(result:dim() == 2)
   return result
end

-- replace APN.FORMATTED and APN.UNFORMATTED with apn.recoded
-- RETURN: mutated data frame
local function createApnRecodedFeature(parcels)
   -- NOTE: This implementation creates potentially large sequences, a
   -- potential problem if the LuaJIT is running.
   -- NOTE: Avoid the sequences seems impossible, since strings are needed
   -- to decode the APN.FORMATTED field
   local vp = makeVp(1, 'createApnRecodedFeature')
   
   local function levels(colName)
      -- return seq of strings
      local seq = {}
      local colIndex = parcels:columnIndex(colName)
      for rowIndex = 1, parcels.t:size(1) do
         table.insert(seq, parcels:getLevel(rowIndex, colIndex))
      end
      if seq and bytesIn(seq) > 1024 * 1024 * 1024 then
         error('large sequence')
      end
      return seq
   end

   local apnsRecoded = 
      bestApns{formattedApns = levels('APN.FORMATTED')
               ,unformattedApns = levels('APN.UNFORMATTED')
               ,na=0/0
              }
   local bestTensor = torch.Tensor{apnsRecoded}:t()

   local recoded = NamedMatrix{tensor=bestTensor,
                               names={'apn.recoded'},
                               levels={}}
   parcels = parcels:dropColumn('APN.FORMATTED'):dropColumn('APN.UNFORMATTED')
   parcels = NamedMatrix.concatenateHorizontally(parcels, recoded)
      
   vp(1, 'parcels', parcels)
   return parcels
end -- function createApnRecodedFeature

-- read some of the 2.3 million geocodings
-- ARGS      : a single table with these elements
-- path      : string, path to geocodings file
-- readLimit : integer; if >0, number of geocoding records that are read
-- verbose   : integer, verbose level
-- RETURN: dataframe with selected rows and all columns
local function readGeocodings(arg)
   local vp = makeVp(2, 'readGeocodings')
   vp(1, 'arg', arg)
   if arg.readLimit == -1 then
      vp(1, string.format('reading all geocodings from %s', 
                          arg.pathToGeocodings))
   else
      vp(1, string.format('reading %d geocodings from %s', 
                          arg.readLimit, arg.pathToGeocodings))
   end

   local numberColumns = {'G APN', 'G LATITUDE', 'G LONGITUDE'}
   local geocodings = NamedMatrix.readCsv{file=arg.pathToGeocodings
                                          ,nRows=arg.readLimit
                                          ,sep='\t'
                                          ,numberColumns=numberColumns
                                          ,verbose=verboseNewFromFile2
                            }
   vp(2, 'read geocoding into NamedMatrix')
   vp(2, 
      'geocodings.t:size()', geocodings.t:size(),
      'geocodings.names', geocodings.names,
      'geocodings.levels', geocodings.level)
   assert(not hasNaN(geocodings.t))

   -- verify that not latitudes or longitudes are 0
   local indexLatitude = geocodings:columnIndex('G LATITUDE')
   local indexLongitude = geocodings:columnIndex('G LONGITUDE')

   local function zeroFound(i)
      local zero = false
      if geocodings.t[i][indexLatitude] == 0 then
         vp(3, 'geocodings[' .. tostring(i) .. ']', geocodings.t[i])
         zero = true
      end
      if geocodings.t[i][indexLongitude] == 0 then
         vp(3, 'geocodings[' .. tostring(i) .. ']', geocodings.t[i])
         zero = true
      end
      return zero
   end

   local hasZero, hasNoZero = geocodings:splitRows(zeroFound)
   vp(2, 'hasZero', hasZero)
   vp(2, 'hasNoZero', hasNoZero)

   return hasNoZero
end -- function readGeocodings


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


-- standardize each numeric column in a dataframe
-- RETURN
-- standardizingMeans : table 
-- standardizingStddevs : table
-- MUTATE: df by adding a new column for each numeric column
local function addStandardizedValues(df, erbose)
   local vp = makeVp(verbose, 'addStandardizedValues')

   local standardizingMeans = {}
   local standardizingStddevs = {}

   -- standardize each number column
   -- accumulate means and standard deviations for each such column
   for _, columnName in ipairs(df:numberColumnNames()) do
      local standardized, mean, stddev = standardize(df:column(columnName))
      standardizingMeans[columnName] = mean
      standardizingStddevs[columnName] = stddev
      local standardizedColumnName = 'standardized.' .. columnName
      df:addColumn(standardizedColumnName, standardized)
   end

   return standardizingMeans, standardizingStddevs
end

-- return sequence of numbers, the factors that represent column values
-- also return decoder table so that decoder[1] == string for factor 1
function classLabels(df, columnName)
   local values = df:column(columnName)

   local decoder = {}
   local nextLevel = 1
   for _, uniqueValue in ipairs(unique(values)) do
      decoder[uniqueValue] = nextLevel
      nextLevel = nextLevel + 1
   end

   local coded = {}
   for _, value in ipairs(values) do
      insert.table(coded, decoder[value])
   end

   return coded, deocoder
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
   assert(type(pathToParcels) == 'string')
   assert(type(readLimit) == 'number')
   assert(type(targetFeatureName) == 'string')

   local parcels = nil
   local base, suffix = splitString(pathToParcels, '.csv')
   vp(2, 'base', base, 'suffix', suffix)
   assert(#base == 2)
   assert(suffix == nil)
   local pathToCache = base[1] .. '.ser'
   vp(2, 'pathToCache', pathToCache)

   -- set obj to cache object, if it exists and is the right value
   local obj = nil
   local parcels = nil
   local f = io.open(pathToCache, 'r')
   if f ~= nil then
      -- cache file exists
      f:close()
      obj = torch.load(pathToCache)
      assert(obj ~= nil)
      if obj.pathToParcels ~= pathToParcels or
         obj.readLimit ~= readLimit or
         obj.targetFeatureName ~= targetFeatureName or
         obj.cacheVersion ~= 'readParcels cache v1' then
         -- cache is for a different set of parameters
         obj = nil
         vp(2, 'cache present but is for different data')
      else
         vp(2, 'used parcel value in cache')
         parcels = obj.parcels
      end
   else
      vp(2, 'cache file does not exit', pathToCache)
   end

   if parcels == nil then
      -- read parcels
      -- cache does not exist or is invalid; create it
      vp(2, 'reading from csv file')
      local numberColumns = {-- description
                             'LAND.SQUARE.FOOTAGE', 'TOTAL.BATHS.CALCULATED',
                             'BEDROOMS', 
                             'PARKING.SPACES', 'UNIVERSAL.BUILDING.SQUARE.FEET',
                             -- location
                             'YEAR.BUILT', 'G LATITUDE', 'G LONGITUDE',
                             -- identification
                             'apn.recoded'}
      
      local factorColumns = {targetFeatureName}
      
      local timer = Timer()
      parcels = NamedMatrix.readCsv{file=pathToParcels
                                    ,nRows=readLimit
                                    ,numberColumns=numberColumns
                                    ,factorColumns=factorColumns
                                    ,nanString=''
                                   }
      vp(2, 'wall clock secs to read parcels file', timer:wallclock())
      
      -- write cache object
      local obj = {pathToParcels=pathToParcels,
                   readLimit=readLimit,
                   targetFeatureName=targetFeatureName,
                   cacheVersion='readParcels cache v1',
                   parcels=parcels}
      torch.save(pathToCache, obj)
      vp(2, 'cache written to', pathToCache)
   end

   vp(1, 'parcels', parcels)
   return parcels
end

-- read the parcels and split them into labeled and unlabeled
local function createLabeledUnlabeled(pathToParcels, readLimit, targetFeatureName)
   local data = readParcels(pathToParcels, readLimit, targetFeatureName)
   local labeled, unlabeled = separate(data, targetFeatureName)
   return labeled, unlabeled
end




--------------------------------------------------------------------------------
-- LOCAL UNIT TEST FUNCTIONS
--------------------------------------------------------------------------------

  
--------------------------------------------------------------------------------
-- GLOBAL FUNCTION imputeMissingFeature
--------------------------------------------------------------------------------

function imputeMissingFeature(clArgs, 
                              readLimit, 
                              targetFeatureName,
                              outputFileSuffix,
                              hp,
                              checkGradient)
   local vp = makeVp(2, 'imputeMissingFeature')
   vp(1, 'clArgs', clArgs)
   vp(1, 'readLimit', readLimit)
   vp(1, 'targetFeatureName', targetFeatureName)
   vp(1, 'outputFileSuffix', outputFileSuffix)
   vp(1, 'hp', hp)
   vp(1, 'checkGradient', checkGradient)

   -- don't use the cache for now
   local useCache = false

   -- validate arguments
   validateAttributes(clArgs, 'table')
   validateAttributes(readLimit, 'number', '>=', -1)
   validateAttributes(targetFeatureName, 'string')
   validateAttributes(outputFileSuffix, 'string')
   validateAttributes(hp, 'table')
   validateAttributes(checkGradient, 'boolean')

   -- setup file paths
   local dirOutput = '../data/v6/output/'
   local pathToParcels = dirOutput .. 'parcels-sfr-geocoded.csv'
   local pathToNeighbors =
      dirOutput ..
      'neighbors-indices-' .. tostring(hp.mPerYear) .. '.csv'
   local pathToOutputBase = dirOutput .. 'parcels-imputed-' .. outputFileSuffix
   local pathToOutput = pathToOutputBase .. '.csv'
   local pathToLogFile = pathToOutputBase .. '.log'
   local cacheFilePath =  -- cacheFilePath includes readLimit
      pathToOutputBase ..
      '-cache-' ..
      ifelse(readLimit == -1,
             'all',
             tostring(readLimit)) ..
      '.csv'

   torch.manualSeed(20110513)
   startLogging(pathToLogFile, clArgs)
   vp(0, 'paths to files')
   vp(1, 
      'pathToParcels', pathToParcels,
      'pathToNeighbors', pathToNeighbors,
      'pathToOutput', pathToOutput,
      'pathToLogFile', pathToLogFile,
      'cacheFilePath', cacheFilePath)

   -- 1 & 2: read parcels and split into labeled and unlabeled
   local pathToCacheFile = 
      dirOutput .. 'imputeMissingFeature-cache-create-labeled-unlabeled.ser'
   local codeVersion = 1
   local usedCache, labeled, unlabeled = nil, nil
   if useCache then
      usedCache, labeled, unlabeled =
      memoizedComputationOnDisk(pathToCacheFile,
                                codeVersion,
                                createLabeledUnlabeled,
                                pathToParcels,
                                readLimit,
                                targetFeatureName)
   else
      usedCache = false
      labeled, unlabeled = createLabeledUnlabeled(pathToParcels, 
                                                  readLimit, 
                                                  targetFeatureName)
   end

   vp(1, 'split used cache?', usedCache)
   validateAttributes(labeled, 'NamedMatrix')     
   validateAttributes(unlabeled, 'NamedMatrix')
   vp(1, 'bytes of memory used after creating labeled and unlabeled', memoryUsed())
   vp(1, 'number of labeled observations', labeled.t:size(1))
   vp(1, 'number of unlabeled observations', unlabeled.t:size(1))
                                
   -- 3: select best hyperparameters
   local bestHp = selectModel(labeled,
                              hp,
                              .60, .20,  -- 60% train 20% validate 20% test
                              cacheFilePath,
                              targetFeatureName,
                              dirOutput,
                              checkGradient)
   
   -- 4: Train on all the labeled data
   local thetaStar = fitModel(labeled, bestHp)

   -- 5: Impute missing values in the unlabeled data
   local prediction = imputeMissing(thetaStar, unlabeled)

   -- 6: Write missing values to CSV file
   writePredictions(predictions, unlabeled)

end -- function imputeMissingFeature


