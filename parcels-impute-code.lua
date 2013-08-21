-- main program to predict imputed parcel codes
-- COMMAND LINE ARGS:
-- --mPerYear F   : hyperparameter kilometers per year
-- --k N           : hyperparamater number of neighbors (N >= 2)
-- --lambda F      : hyperparameter importance of regularizer
-- --known S       : filename for known pairs (apn | features, code)
--                   ex: parcels-HEATING.CODE-known-train.pairs
-- --slice N       : slice of stdin in to read
--                   specify 'all' if running with Hadoop, as Hadoop has
--                   already sliced the file
--                   specify N if running under linux, to simulate slicing
-- --of M          : number of slices --
-- FILES 
-- stdin           : pairs file (apn | features [,code])
--                   code, if present, is ignored
--                   can be a slice
--                   ex: parcels-HEATING.CODE-known-val.pairs
-- stdout          : pairs file (apn | mPerYear, k, lambda, predictedCode)
--                   first 3 values are hyperparameters (see other args)
--                   predictedCode is string predicted
-- -- parcels-impute-code-<mPerYear>-<k>-<lambda>-log.txt : log file
--
-- Copyright 2013 Roy E. Lowrance
-- Copying permission is given in the file COPYING

require 'distancesSurface'
require 'kernelEpanechnikovQuadraticKnn'
require 'localLogRegNn'
require 'Log'
require 'makeVp'
require 'parseCommandLine'
require 'SliceReader'
require 'standardize'
require 'Timer'
require 'viewAsColumnVector'

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function parse(arg)
   local clArgs = {}

   clArgs.mPerYear = tonumber(parseCommandLine(arg, 'value', '--mPerYear'))
   validateAttributes(clArgs.mPerYear, 'number', '>=', 0)

   clArgs.k = tonumber(parseCommandLine(arg, 'value', '--k'))
   validateAttributes(clArgs.k, 'number', 'integer', '>=', 2)

   clArgs.lambda = tonumber(parseCommandLine(arg, 'value', '--lambda'))
   validateAttributes(clArgs.lambda, 'number', '>=', 0)

   clArgs.known = parseCommandLine(arg, 'value', '--known')
   validateAttributes(clArgs.known, 'string')

   clArgs.slice = tonumber(parseCommandLine(arg, 'value', '--slice'))
   validateAttributes(clArgs.slice, 'number', 'integer', '>=', 1)

   clArgs.of= tonumber(parseCommandLine(arg, 'value', '--of'))
   validateAttributes(clArgs.of, 'number', 'integer', '>=', clArgs.slice)

   return clArgs
end


-- return open Log 
local function makeLog(clArg, outputDir)
   local vp = makeVp(0, 'makeLog')
   validateAttributes(clArg, 'table')
   validateAttributes(outputDir, 'string')
   local args = string.format('%f-%d-%f-%d-%d',
                              clArg.mPerYear,
                              clArg.k,
                              clArg.lambda,
                              clArg.slice,
                              clArg.of)
   local logFileName = string.format('parcels-imput-code-log-%s.txt',
                                     args)
   vp(1, 'logFileName', logFileName)
   local log = Log(outputDir .. logFileName)
   return log
end

-- extract first 8 numbers from string, return as 1D Tensor
local function extract8numbers(s)
   local vp = makeVp(0, 'extract8numbers')
   vp(1, 's', s)
   local f1,f2,f3,f4,f5,f6,f7,f8 = 
      string.match(s, '^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),.*$')
   local result = torch.Tensor{tonumber(f1),
                               tonumber(f2),
                               tonumber(f3),
                               tonumber(f4),
                               tonumber(f5),
                               tonumber(f6),
                               tonumber(f7),
                               tonumber(f8)}
   vp(1, 'result', result)
   return result
end


-- extract the code (a string), which is in the last position
local function extractCode(s)
    local vp = makeVp(0, 'extractCode')
    vp(1, 's', s)
    local result = string.match(s, '^.*,(.*)$')
    vp(1, 'result', result)
    return result
end

-- convert sequence of strings to 1D Tensor of integers 1, 2, ...
-- RETURNS
-- tensor  : 1D Tensor of integers
-- codeMap : table such that codeMap[integer] = string 
local function makeTargets(codes)
    local vp = makeVp(0, 'makeTargets')
    vp(1, 'codes', codes)
    local u = unique(codes)
    vp(2, 'u', u)

    local map = {}
    local codeMap = {}
    for i, code in ipairs(u) do
        map[code] = i
        codeMap[i] = code
    end
    vp(2, 'map', map)

    local result = torch.Tensor(#codes)
    for i, code in ipairs(codes) do
        result[i] = map[code]
    end
    vp(2, 'result', result)
    vp(2, 'codeMap', codeMap)
    return result, codeMap
end

-- split pair (key \t value) into its parts
local function splitPair(s)
   local key, value = string.match(s, '^(.*)%\t(.*)$')
   return key, value
end


-- read pairs (apn | 8 features [,code])
-- RETURNS
-- features : 2D Tensor
-- codes    : sequence of strings
local function readKnown(path, readLimit)
   local vp = makeVp(0, 'readKnown')
   vp(1, 'path', path)
   vp(1, 'readLimit', readLimit)
   local nFeatures = 8  -- this is hard-coded later in string.match
   local f = io.open(path, 'r')
   assert(f, 'unable to open ' .. path)

   -- do something with each line in the file
   -- return number of records for which action performed
   local function forEachLine(action)
      local vp = makeVp(0, 'forEachLine')
      vp(1, 'action', action)
      local f = io.open(path, 'r')
      assert(f, 'unable to open ' .. path)
      vp(2, 'f', f)
      local nRead = 0
      local nProcessed = 0
      for line in f:lines() do
         nRead = nRead + 1
         if readLimit > -1 and nRead > readLimit then 
            break 
         else 
            action(nRead, line)
            nProcessed = nProcessed + 1
         end
      end
      f:close()
      return nProcessed
   end
      
   -- pass 1 : count lines == number of rows in result tensor
   local nRead = forEachLine(function() end)

   -- allocate result tensors
   local features = torch.Tensor(nRead, nFeatures)
   local codes = {}
   vp(2, 'features size', features:size())

   -- pass 2 : read and store values in features tensor
   local function parseStore(nRead, line)
      local vp = makeVp(0, 'parseStore')
      vp(1, 'nRead', nRead)
      vp(1, 'line', line)
      local key, value = splitPair(line)
      vp(2, 'key', key)
      vp(2, 'value', value)
      features[nRead] = extract8numbers(value)
      table.insert(codes, extractCode(value))
   end

   forEachLine(parseStore)

   vp(1, 'features', features)
   vp(1, 'codes', codes)
   return features, codes
end

-- determine if 1D Tensor has any zero values
local function hasNoZeroes(t)
   local nZeroes = torch.sum(torch.eq(t, 0))
   return nZeroes == 0
end

-- return 1D Tensor of weights
local function getWeights(known, query, clArgs, log)
   local vp = makeVp(0, 'getWeights')
   vp(1, 'query', query)
   vp(1, 'clArgs', clArgs)
   vp(1, 'log', log)
   validateAttributes(known, 'Tensor', '2d')
   validateAttributes(query, 'Tensor', '1d')
   validateAttributes(clArgs, 'table')  -- contains hyperparameters
   validateAttributes(log, 'Log')
   local nObs = known:size(1)

   -- determine columns with certain features
   local function checkColumns(t, columns)
       assert(math.abs(t[columns['latitude']] - 33) < 2)
       assert(math.abs(t[columns['longitude']] + 118) < 2)
       assert(math.abs(t[columns['year']] - 1950) < 50)
   end

   vp(2,'known[1]', known[1])
   local columns = {latitude = 1,
                    longitude = 2,
                    year = 3}
   checkColumns(known[1], columns)
   vp(2, 'query', query)
   checkColumns(query, columns)

   local distances = distancesSurface(query, known, clArgs.mPerYear, columns)
   local weights = kernelEpanechnikovQuadraticKnn(distances, clArgs.k)
   local weights = weights / torch.sum(weights)  -- weights sum to 1.0
   assert(weights:size(1) == nObs)
   return weights
end

-- create output record (apns \t hyperparameters, prediction)
local function makeOutputRecord(clArgs, apn, predictionString)
    local vp = makeVp(0, 'makeOutputRecord')
    vp(1, 'clArgs', clArgs, 'apn', apn, 'predictionString', predictionString)
    local s = string.format('%s\t%f,%d,%f,%s\n',
                            apn,
                            clArgs.mPerYear,
                            clArgs.k,
                            clArgs.lambda,
                            predictionString)
    vp(1, 's', s)
    return s
end

-- convert target integer into a code string
local function codeString(prediction, codeMap)
    local vp = makeVp(0, 'codeString')
    vp(1, 'prediction', prediction, 'codeMap', codeMap)
    assert(prediction > 0)
    assert(prediction <= #codeMap)
    return codeMap[prediction]
end


-------------------------------------------------------------------------------
-- MAIN
-------------------------------------------------------------------------------

local function main()
   local vp = makeVp(0, 'main')
   torch.manualSeed(123)
   local clArgs = parse(arg)
   vp(1, 'clArgs', clArgs)

   local outputDir = '../data/v6/output/'
   local log = makeLog(clArgs, outputDir)
   assert(log ~= nil)
   log:logTable('clArgs', clArgs)
   stop()

   local readLimit = -1
   --readLimit = 1000 -- while debugging
   -- read features (2D Tensor) and targets (seq)
   local known, codes = readKnown(clArgs.known, readLimit)
   log:log('read %d known features and targets',
           known:size(1))
   local targets, codeMap = makeTargets(codes)  -- convert seq of strings to 1D Tensor
   log:log('there are %d unique codes', #codeMap)
   vp(2, 'targets head', head(targets), 'codeMap', codeMap)
   local targets2D = viewAsColumnVector(targets)
   codes = nil
   vp(2, 'known')
   local stdKnown, means, stddevs = standardize(known) -- center values
   vp(2, 'means', means, 'stddevs', stddevs)
   assert(hasNoZeroes(stddevs), 'stddevs contain a zero value')

   -- predict the code for a specific input record
   local nPredictions = 0  -- to trigger garbage collection and reporting
   local gcFrequency = 10
   local reportFrequency = 10
   local function predictCode(inputRecord)
       local timerAll = Timer()
       key, value = splitPair(inputRecord)
       local query = extract8numbers(value)
       vp(2, 'value', value, 'query', query) 
       local stdQuery = standardize(query, means, stddevs)
       vp(2, 'stdQuery', stdQuery)
       local timerWeights = Timer()
       local weights = getWeights(known, query, clArgs, log)
       local weights2D = viewAsColumnVector(weights)
       local timeWeights = timerWeights:cpu()   
       local checkGradient = false  -- check gradient in early debugging
       local timerPredict = Timer()
       -- predict target number in {1, 2, ..., nTargets}
       local predicted = localLogRegNn(stdKnown,
                                       targets2D,
                                       weights2D,
                                       viewAsColumnVector(stdQuery):t(),
                                       clArgs.lambda,
                                       checkGradient)
       local timePredict = timerPredict:cpu()
       local timerWrite = Timer()
       local outputRecord = makeOutputRecord(clArgs, 
                                             key, 
                                             codeString(predicted, codeMap))
       io.stdout:write(outputRecord)
       log:log(outputRecord)  -- at least while debugging
       local timeWrite = timerWrite:cpu()
       -- periodically collect garbage
       local timerGarbage = Timer()
       nPredictions = nPredictions + 1
       if nPredictions % gcFrequency == 1 then
           local used = memoryUsed()
           log:log('memory used = %d', used)
       end
       local timeGarbage = timerGarbage:cpu()
       local timeAll = timerAll:cpu()
       if nPredictions % reportFrequency == 1 then
          log:log('cpu secs: %0.2f weights %0.2f predict %0.2f write %0.2f gc %0.2f all',
                   timeWeights, timePredict, timeWrite, timeGarbage, timeAll)
       end
       if nPredictions == 1 then stop() end
   end
  
   -- predict code for each input record in slice
   local sr = SliceReader(io.stdin, clArgs.slice, clArgs.of)
   vp(2, 'sr', sr)
   local nRecords = sr:forEachRecord(predictCode)
   log:log('processed %d input records in the slice', nRecords)
end

main()

