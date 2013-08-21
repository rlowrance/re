-- impute.lua
-- impute values of missing variables in obs2R using obs1A to create
-- features in obs2A ("imputed-FEATURE.csv")

-- TODO: try with L-BFGS, once Clement has debugged

-- results from SGD
-- features: foundation
-- epochs           100
-- loss        

require 'CsvUtils'
require 'LogisticRegression'

--------------------------------------------------------------------------------
-- read command line, setup directories, start logging
--------------------------------------------------------------------------------

do
   local cmd = torch.CmdLine()
   cmd:text('Impute missing features in 2R using 1A')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-dataDir', '../../data/', 'Path to data directory')
   cmd:option('-feature','','Feature to impute in {"foundation", "heating"}')
   cmd:option('-SgdEpochs',100,
              'Number of epochs for stochastic gradient descent')
   params = cmd:parse(arg)

   -- check for missing parameter
   function missing(name) error('missing parameter - ' .. name) end
   if params.feature == '' then missing('feature') end

   -- setup directories
   dirObs1AFeatures = params.dataDir .. 'generated-v4/obs1A/features/'
   dirObs2RFeatures = params.dataDir .. 'generated-v4/obs2R/features/' 
   dirAnalysis = params.dataDir .. 'generated-v4/obs2R/analysis/'
   
   dirResults = dirAnalysis .. cmd:string('impute', params, {})

   -- start logging
   os.execute('mkdir' .. dirResults)
   cmd:log(dirResults .. '-log.txt', params)

end

--------------------------------------------------------------------------------
-- read obs1A data and train the logistic regression model
--------------------------------------------------------------------------------

function getNumClasses(targets)
   local present = {}
   for i, target in ipairs(targets) do
      if not present[target] then
         present[target] = true
      end
   end
   local result = 0
   for _, _ in pairs(present) do
      result = result + 1
   end
   return result
end

function getNumDimensions(tensor)
   return tensor:size(2)
end

-- return a trained  model
-- for now, use only stochastic gradient descent
function trainModel(features, targets)
   local numObservations = #targets
   local numClasses = getNumClasses(targets)
   local numDimensions = getNumDimensions(features)
   print()
   print('Training logistic regression model')
   print('numObservations', numObservations)
   print('numClasses', numClasses)
   print('numDimensions', numDimensions)

   local logisticRegression = LogisticRegression(features, 
                                                 targets,
                                                 numClasses,
                                                 numDimensions)

   local function nextBatch(features, prevIndices)
      if prevIndices == nil then
         return {1}
      else
         local onlyIndex = prevIndices[1]
         if onlyIndex >= numObservations then
            return nil
         else
            return {onlyIndex + 1}
         end
      end
   end

   local opt = {algo = 'sgd',
                numEpochs = params.SgdEpochs,
                verboseBatch = false,
                verboseEpoch = true,
                optimParams = {learningRate = 1e-3,
                               learningRateDecay = 1e-4,
                }
   }

   logisticRegression:train(nextBatch, opt)
   return logisticRegression:getModel()
end

--------------------------------------------------------------------------------
-- define how to impute feature foundation
--------------------------------------------------------------------------------

-- return array of targets values, each a string
function readTargets(featureName)
   inFilePath = dirObs1AFeatures .. featureName .. '.csv'
   targetArray = CsvUtils.read1String(inFilePath)
   return targetArray
end

-- return tensor of input features that are known to the observation set
function readInputs(numObservations, obs)
   print()
   print('Reading inputs', numObservations, obs)
   local numFeatures = 18 -- number of append function calls below
   local result = torch.Tensor(numObservations,numFeatures)
   
   local dirFeatures
   if     obs == '1A' then dirFeatures = dirObs1AFeatures
   elseif obs == '2R' then dirFeatures = dirObs2RFeatures
   else error('bad obs = ', obs) end

   local featureIndex = 0
   local function append(fileBaseName)
      featureIndex = featureIndex + 1
      local array = 
         CsvUtils.read1Number(dirFeatures .. fileBaseName .. '.csv')
      assert(numObservations == #array, #array)
      if false then
         print('readInput #array', #array, 'featureIndex', featureIndex)
         print('result:size()', result:size())
      end
      for obsIndex = 1,#array do
         if false and obs == '2R' then -- isolate error
            print(array[obsIndex])
            print(result[obsIndex])
            print(result[obsIndex][featureIndex])
         end
         result[obsIndex][featureIndex] = array[obsIndex]
      end
      print('read', #array, obs, fileBaseName)
      assert(numObservations == #array)
   end

   append('ACRES-log-std')
   append('BEDROOMS-std')
   append('census-avg-commute-std')
   append('census-income-log-std')
   append('census-ownership-std')
   append('day-std')
   append('IMPROVEMENT-VALUE-CALCULATED-log-std')
   append('LAND-VALUE-CALCULATED-log-std')
   append('latitude-std')
   append('LIVING-SQUARE-FEET-log-std')
   append('longitude-std')
   append('PARKING-SPACES-std')
   append('percent-improvement-value-std')
   append('POOL-FLAG-is-1')
   append('SALE-AMOUNT-log-std')
   append('TOTAL-BATHS-CALCULATED-std')
   append('TRANSACTION-TYPE-CODE-is-3')
   append('YEAR-BUILT-std')

   print('all features read')
   return result
end

targetStringToInteger = {}
function convertTargetStringsToIntegers(targets)
   local nextInteger = 0
   for _, v in pairs(targets) do
      if targetStringToInteger[v] == nil then
         nextInteger = nextInteger + 1
         targetStringToInteger[v] = nextInteger
      end
   end
   print()
   print('Target encoding from strings to integers')
   for k, v in pairs(targetStringToInteger) do
      print(k, v)
   end
   local result = {}
   for _, v in pairs(targets) do
      local integer = targetStringToInteger[v]
      assert(integer, v)
      result[#result + 1] = integer
   end
   return result
end

function convertTargetStringToInteger(targetString)
   local result = targetStringToInteger[targetString]
   assert(result, targetString)
   return result
end


-- return index of best estimate
function estimateTarget(model, input)
   local logProbs = model:forward(input)
   local bestI = 0
   local bestLogProb = - math.huge
   for i=1,logProbs:size(1) do
      if logProbs[i] > bestLogProb then
         bestLogProb = logProbs[i]
         bestI = i
      end
   end
   --print('estimateTarget', bestI, logProbs)
   return bestI
end

-- count occurences of each target value      
do
   local Counter = torch.class('Counter')
   
   function Counter:__init()
      self.table = {}
      self.totalCount = 0
   end

   function Counter:count(value)
      if self.table[value] then
         self.table[value] = self.table[value] + 1
      else
         self.table[value] = 1
      end
      self.totalCount = self.totalCount + 1
   end
   
   function Counter:print()
      for k,v in pairs(self.table) do
         print(string.format('value %q occurred %d times (%0.3f)',
                             k, v, v / self.totalCount))
      end
   end
end

function testOn1A(model, inputs, targets)
   Validations.is2DTensor(inputs, 'inputs')
   print()
   print('Results from imputing on Obs 1A (versus known target values)')
   local counterEstimates = Counter()
   local counterTargets = Counter()
   local countCorrect = 0
   local countIncorrect = 0
   for i=1,inputs:size(1) do
      local input = inputs[i]
      local estimate = estimateTarget(model, input)
      counterEstimates:count(estimate)
      counterTargets:count(targets[i])
      if estimate == targets[i] then
         countCorrect = countCorrect + 1
      else
         countIncorrect = countIncorrect + 1
      end
   end
   print('Number of correct estimates', countCorrect)
   print('Number of incorrect estimates', countIncorrect)
   assert(countCorrect + countIncorrect == #targets)
   print('Total number of estimates', #targets)
   print('Fraction correct', countCorrect / #targets)
   print()
   print('Distribution of actual target values')
   counterTargets:print()
   print()
   print('Distribution of estimated target values')
   counterEstimates:print()
end

-- impute features for 2R and write csv files to obs2A/features/<files>
function imputeFeatures(featureName, featureValues, model, apns, apnsTargets)
   -- build map of apns to known targets
   local knownTargets = {}
   local countInconsistentTargets = 0
   local countKnownApns = 0
   for i,apn in ipairs(apns) do
      local alreadySeen = knownTargets[apn]
      if alreadySeen then
         if alreadySeen ~= apnsTargets[i] then
            print('apn', apn, 
                  'first target', alreadySeen, 
                  'new target', apnsTargets[i])
            countInconsistentTargets = countInconsistentTargets + 1
         end
      else
         knownTargets[apn] = apnsTargets[i]
         countKnownApns = countKnownApns + 1
      end
   end
   print()
   print('Imputing features for 2R')
   print('Known apns', countKnownApns)
   print(' Of which, number inconsistent', countInconsistentTargets)
   print()
   local numObservations =1513786
   local inputs = readInputs(numObservations, '2R')
   
   -- create and write the estimates
   outFileName = featureName .. '.csv'
   outFilePath = dirObs2RFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write(featureName .. '\n')
   local estimates = {}
   local countAlreadyKnown = 0
   local countEstimates = Counter()
   local countConsistent = 0
   local countInconsistent = 0
   for i=1,inputs:size(1) do
      local input = inputs[i]
      local estimate = estimateTarget(model, input)
      countEstimates:count(estimate)
      estimates[#estimates + 1] = estimate
      local knownTarget = knownTargets[apns[i]]
      --if knownTarget then print('knownTarget', knownTarget, apns[i]) end
      if knownTarget then
         countAlreadyKnown = countAlreadyKnown + 1
         local knownTargetInteger = convertTargetStringToInteger(knownTarget)
         if knownTargetInteger == estimate then
            countConsistent = countConsistent + 1
         else
            --print('inconsistent', i, knownTargetInteger, estimate)
            countInconsistent = countInconsistent + 1
         end
         assert(knownTargetInteger, knownTargetInteger)
         out:write(knownTargetInteger)
      else
         out:write(estimate)
      end
      out:write('\n')
   end
   out:close()
   print('Wrote estimates for', featureName, 'to', outFilePath)
   print('Wrote', #estimates, 'estimates')
   print(' Of which already known', countAlreadyKnown)
   print('  Of which, consistent estimate and actual', countConsistent)
   print('  Of which, inconsistent estimate and actual', countInconsistent)
   print()
   print('Distribution of imputed target values')
   countEstimates:print()
end


function impute(featureName)
   local apns = CsvUtils.read1String(dirObs1AFeatures .. 'apns.csv')
   local targetsStrings = readTargets(featureName)
   local targetsIntegers = convertTargetStringsToIntegers(targetsStrings)
   local numObservations = #targetsIntegers
   print('Number of observations=', numObservations)
   for i=1,20 do print('targetsStrings', 
                       i, targetsStrings[i], targetsIntegers[i]) end
   local inputs = readInputs(numObservations, '1A')
   local model = trainModel(inputs, targetsIntegers)
   testOn1A(model, inputs, targetsIntegers)
   imputeFeatures(featureName, featureValues, model, apns, targetsStrings)
end

--------------------------------------------------------------------------------
-- dispatch
--------------------------------------------------------------------------------

if     params.feature == 'foundation' then impute('FOUNDATION-CODE')
elseif params.feature == 'heating'    then impute('HEATING-CODE')
elseif params.feature == 'location'   then impute('LOCATION-INFLUENCE-CODE')
elseif params.feature == 'parking'    then impute('PARKING-TYPE-CODE')
elseif params.feature == 'roof'       then impute('ROOF-TYPE-CODE')
else
   error('features ' .. params.feature .. ' is not known')
end


