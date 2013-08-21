-- HpSearch.lua
-- class to conduct hyperparameter search
-- used by hp-search-XXX.lua modules

-- API overview
if false then
   hps = HpSearch(makeAlphas, modelFit, programName, resultsLog, resultsPrint)
   hps:run()
end

if false then
   -- caller requires these
   require 'makeVerbose'
   require 'modelUseKernelSmoother'
   require 'parseOptions'
   require 'printOptions'
   require 'verify'
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('HpSearch')

function HpSearch:__init(dropRedundant,
                         makeAlphas, 
                         modelFit,
                         modelUse,
                         programName, 
                         resultsLog, 
                         resultsReport)
   -- ARGS
   -- dropRedundant : if true, the features files is modified such that
   --                 features that are linear combinations of others are
   --                 dropped. This allow Llr to work.
   -- makeAlphas    : function(options) --> sequence of model identifiers
   -- modelFit      : function(removedFold, kappa, modelState, options) 
   --                 --> model
   -- modelUse      : function(alpha, model, i, modelState, options)
   --                 --> ok, estimate
   -- programName   : string, name of main program (without .lua)
   -- resultsLog    : function(log, lossTable, coverageTable, options)
   -- resultsReport : function(dirOutput, 
   --                         options, lossTable, coverageTable, nFolds)

   local v, isVerbose = makeVerbose(true, 'HpSearch:__init')
   verify(v,
          isVerbose,
          {{dropRedundant, 'dropRedundant', 'isBoolean'},
           {makeAlphas, 'makeAlphas', 'isFunction'},
           {modelFit, 'modelFit', 'isFunction'},
           {modelUse, 'modelUse', 'isFunction'},
           {programName, 'programName', 'isString'},
           {resultsLog, 'resultsLog', 'isFunction'},
           {resultsReport, 'resultsReport', 'isFunction'}})

   self._dropRedundant = dropRedundant
   self._makeAlphas = makeAlphas
   self._modelFit = modelFit
   self._modelUse = modelUse
   self._programName = programName
   self._resultsLog = resultsLog
   self._resultsReport = resultsReport
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function HpSearch:run()
   print('********************************************************************')

   local v = makeVerbose(true, 'main')

   -- keep a running list of debug numbers
   -- and allow debugging to be activated from the source code
   local debug
   debug = 0 -- no debugging
   
   local options, dirResults, log, dirOutput = 
      mainStart(arg, 
                'split input files into train, test files',
                {{'-cvLoss', 'abs', 'alt is squared'},
                 {'-dataDir', '../../data/', 'path to data directory'},
                 {'-debug', 0, '0 for no debugging code'},
                 {'-inputLimit', 0, 'if not 0, read this many input recs'},
		 {'-maxConsecutiveNotOk', 0, 'if not 0, allow this many'},
                 {'-obs', '', 'observation set'},
                 {'-programName', self._programName, 'Name of program'},
                 {'-seed', 27, 'random number seed'},
                 {'-test', 1, '0 for production, 1 to test'}})

   -- debug settings used
   -- NOTE: there is code that looks for these values, so use a higher value
   -- for the next debugging session
   -- debug==3: find problem in dropping columns
   -- debug==4: find problem with lambda = 0 for Kwavg algo

   local log = options.log

   if options.debug == 0 and debug ~= 0 then
      options.debug = debug
   end
   
   if  debug > 0 then 
      options.debug = debug
      log:log('DEBUGGING: toss results')
   end
   
   -- validate options
   assert(options.cvLoss == 'abs' or options.cvLoss == 'squared',
          'invalid options.cvLoss')
   assert(options.obs == '1A' or options.obs == '2R',
          'invalid options.obs')
   assert(options.test == 0 or options.test == 1,
          'invalid options.test')
   
   if options.test == 1 then
      -- set options implied by test == 1
      options.inputLimit = 1000
      log:log('TESTING')
   end
   
   -- read the training data
   local nObservations, trainingData = readTrainingData(options,
                                                        log, 
                                                        self._dropRedundant)

   -- examine feature columns for all zero features
   -- stop if that happens
   v('trainingData', trainingData)
   self:_verifyNoAllZeroFeatures(data.features, 
                                 trainingData.featureNames, 
                                 log)
   
   -- setup cross validation
   -- Each alpha is a tuning parameter
   -- In this case, alpha is lambda, the number of neighbors considered
   
   -- Experiments with different alphas
   local alphas = self._makeAlphas(options)
   
   -- log the alpha values
   log:log('all alphas')
   for _, alpha in ipairs(alphas) do
      v('alpha', alpha)
      v('type(alpha)', type(alpha))
      if type(alpha) == 'number' then
         log:log(' %f', alpha)
      elseif type(alpha) == 'table' then
         log:log(' {%f, %f}', alpha[1], alpha[2])
      else
         log:log(' %s', tostring(alpha))
      end
   end
   
   
   -- do cross validation
   local nFolds = 5
   
   local modelState = {}

   
   local alphaStar, lossTable, coverageTable =
      crossValidation(alphas, 
                      nFolds, 
                      nObservations,
                      trainingData.features,
                      trainingData.prices,
                      self._modelFit,
                      self._modelUse,
                      modelState,
                      options)
      
   -- write log and report in file
   v('alphas', alphas)
   v('alphaStar', alphaStar)
   v('lossTable', lossTable)
   v('coverageTable', coverageTable)
   
   self._resultsLog(lossTable, coverageTable, options)
   self._resultsReport(lossTable, coverageTable, nFolds, options)
   
   
   -- cvLossInstance:wrapup(alphas, dirOutput, log, options)

   mainEnd(options)
end -- run

--------------------------------------------------------------------------------
-- PRIVATE METHODS
--------------------------------------------------------------------------------

local function countZeroValues(features, colIndex)
   local n = 0
   for rowIndex = 1, features:size(1) do
      if features[rowIndex][colIndex] == 0 then
         n = n + 1 
      end
   end
   return n
end -- countZeroValues

function HpSearch:_verifyNoAllZeroFeatures(features, colNames, log)
   assert(features:size(2) == #colNames)
   local nAllZeroes = 0
   log:log('of %d observations, number with all zero feature values',
           features:size(1))
   for i = 1, #colNames do
      local countZero = countZeroValues(features, i)
      log:log(' %36s (%2d): %7d',
              colNames[i], i, countZero)
      if countZero == features:size(1) then
         nAllZeroes = nAllZeroes + 1
      end
   end
   log:log('number of feature columns that are all zeroes: %d',
           nAllZeroes)
   assert(nAllZeroes == 0,
          'stopping, since features has an all zeroes column')
   --halt()
end -- _verifyNoAllZeroFeatures