-- CompleteMatrix.lua
-- define worker class for complete-matrix.lua, which does this:
-- read estimates of transactions, determine sparse error matrix, and
-- complete matrix for all time periods and APNs

-- Input files:
-- FEATURES/apns.csv
-- FEATURES/dates.csv
-- FEATURES/SALE-AMOUNT-log.csv
-- ANALYSIS/create-estimates-lua-...-which=mc/estimates-mc.csv

-- Output files:
-- ANALYSIS/RESULTS/all-estimates-mc.csv
-- ANALYSIS/RESULTS/log.txt

require 'paths'

require 'affirm'
require 'ApnIndex'
require 'assertEqual'
require 'checkGradient'
require 'Completion'
require 'CsvUtils'
require 'crossValidation'
require 'createResultsDirectoryName'
require 'DateIndex'
require 'IncompleteMatrix'
require 'Log'
require 'makeVerbose'
require 'printOptions'
require 'setRandomSeeds'
require 'sortedKeys'
require 'TimerCpu'

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('CompleteMatrix')

function CompleteMatrix:__init()
   -- define option defaults and explanations

   self.optionDefaults = {}
   self.optionExplanations = {}
   
   local function def(option, default, explanation)
      self.optionDefaults[option] = default
      self.optionExplanations[option] = explanation
   end

   def('algo',              '', 'Name of algorithm; in {knn, kwavg, llr}')
   def('col',               '', 'Definition of columns; in {month, quarter)')
   def('dataDir',           '../../data/','Path to data directory')
   def('lambda',            1e-9, 'Regularizer constant')
   def('obs',               '', 'Observation set')
   def('radius',            0, 'Value of radius parameter')
   def('rank',              0, 'Elements in each latent variable')
   def('seed',              27, 'Random number seeds for torch and lua')
   def('test',              0, 'Set to 1 for testing (TODO: truncate input)')
   def('which',             '', 'In {checkGradient,complete, ' ..
                                 'hpCg,hpLbfgs,hpSgd,rankSearch,time')
   def('write',             0, 'Whether to write the completed matrix')
   def('yearFirst',         0, 'First year to consider')

end

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function CompleteMatrix:getOptionDefaults()
   -- return table of option names and default values for each
   return self.optionDefaults
end

function CompleteMatrix:getOptionExplanations()
   -- return table of option names and explanations for each
   return self.optionExplanations
end

function CompleteMatrix:worker(options, mainProgramName)
   -- main program
   local p = makeVerbose(true, 'CompleteMatrix:worker')
   assert(options)
   assert(mainProgramName)

   -- validate options and set default values
   options = self:_validateOptions(options)

   -- set random number seeds
   setRandomSeeds(options.seed)

   local directories = self:_setupDirectories(options, mainProgramName)

   local log = self:_startLogging(directories.results)

   -- log the command line parameters
   printOptions(options, log)

   -- log directories used
   log:log('\nDirectories used')
   for k, v in pairs(directories) do
      log:log('%-20s = %s', k, v)
   end

   local paths = self:_makePaths(directories, options)
   log:log('\nPaths to files')
   for k, v in pairs(paths) do
      log:log('%-25s = %s', k, v)
   end
   
   -- define how to convert dates to column indices and APNs to row indices
   local apnIndex = ApnIndex()
   local dateIndex = DateIndex(options.col, options.yearFirst)

   -- read incomplete estimates
   incompleteMatrix = self:_makeIncompleteMatrix(paths.incompleteEstimates,
                                                 apnIndex, dateIndex,
                                                 options.yearFirst,
                                                 log,
                                                 options)
   p('incompleteMatrix', incompleteMatrix)

   -- do whichever computation was requested
   if options.which == 'checkGradient' then
      whichCheckGradient(incompleteMatrix)
   elseif options.which == 'complete' then
      self:_whichComplete(directories.results, 
                          incompleteMatrix, 
                          options,
                          apnIndex,
                          dateIndex,
                          log)
   elseif options.which == 'hpCg' then
      self:_whichHpCg(directories.results, 
                      incompleteMatrix, 
                      options.lambda,
                      options.rank,
                      log)
   elseif options.which == 'hpLbfgs' then
      self:_whichHpLbfgs(directories.results, 
                      incompleteMatrix, 
                      options.lambda,
                      options.rank,
                      log)
   elseif options.which == 'hpSgd' then
      self:_whichHpSgd(directories.results, 
                       incompleteMatrix, 
                       options.lambda,
                       options.rank,
                       log)
   elseif options.which == 'rankSearch' then
      self:_whichRankSearch(directories,
                            incompleteMatrix,
                            options,
                            log)
   elseif options.which == 'time' then -- TODO: increase time to 1 hour
      self:_whichTime(directories.results, 
                      incompleteMatrix, 
                      options.rank,
                      options.lambda,
                      log)
   end
   
   printOptions(options, log)

   log:log('torch.initialSeed()', torch.initialSeed())
   
   if options.test == 1 then 
      log:log('TESTING')
   end

   log:log('consider commiting the source code')
   
   log:log('\nfinished')
   log:close()
end -- worker

--------------------------------------------------------------------------------
-- PRIVATE METHOD IN ALPHABETIC ORDER
--------------------------------------------------------------------------------

function CompleteMatrix:_checkNonNegative(options, fieldName)
   local fieldValue = options[fieldName]
   if fieldValue == nil then
      self:_optionError('option ' .. fieldName .. ' was not supplied')
   end
   if fieldValue < 0 then
      self:_optionError('option ' .. fieldName .. ' must be non-negative')
   end
end

function CompleteMatrix:_checkPositive(options, fieldName)
   local fieldValue = options[fieldName]
   if fieldValue == nil then
      self:_optionError('option ' .. fieldName .. ' was not supplied')
   end
   if fieldValue <= 0 then
      self:_optionError('option ' .. fieldName .. ' must be non-negative')
   end
end


function CompleteMatrix:_date2Year(date)
   -- convert date to year
   return math.floor(date / 10000)
end

do
   -- unit test method _date2Year
   local function check(expected, date)
      cm = CompleteMatrix()
      assertEqual(expected, cm:_date2Year(date))
   end

   check(1234, 12345678)
end

function CompleteMatrix:_makeIncompleteMatrix(pathInput, 
                                              apnIndex, 
                                              dateIndex, 
                                              yearFirst, 
                                              log, 
                                              options)
   -- return incomplete matrix read from file
   -- only save if date is in range [yearFirst, 2009]
   -- ARGS:
   -- pathInput : path to incomplete matrix file
   -- apnIndex  : instance of ApnIndex
   -- dateIndex : instance of DateIndex
   -- firstYear : number, first year in the incomplete matrix
   -- log       : instance of Log
   -- options   : table of command line options
   -- RETURNS: instance of an IncompleteMatrix
   
   assert(pathInput)
   assert(apnIndex)
   assert(dateIndex)
   assert(yearFirst)
   assert(log)
   assert(options)

   local trace = true
   if trace then
      print('makeIncompleteMatrix')
      print(' pathInput', pathInput)
      print(' dateIndex', dateIndex)
      print(' yearFirst', yearFirst)
   end
   local start = os.clock()

   -- read input CSV file
   local input = io.open(pathInput)
   if input == nil then
      print('unable to open incomplete estimate file', pathInput)
      os.exit(1)
   end

   local header = input:read() -- don't use the header

   -- convert each valid row in the CSV to an error in the incomplete matrix
   local im = IncompleteMatrix()
   local countSkippedDate = 0
   local countSkippedFormat = 0
   local countSkippedSameElement = 0
   local countUsed = 0
   local countInput = 0

   -- maintain table transactionsFor[apn] = {trans1, ..., transN}
   local transactionsFor = {}
   local function insertTransactionFor(apn, date, actual, estimate)
      local trace = false
      if trace then
         print('insertTransactionFor apn, date, actual, estimate',
               apn, date, actual, estimate)
         print('types', type(apn), type(date), type(actual), type(estimate))
      end
      assert(apn)
      assert(type(apn) == 'string')
      assert(date)
      assert(type(date) == 'string')
      assert(actual)
      assert(type(actual) == 'number')
      assert(estimate)
      assert(type(estimate) == 'number')
      local newValue = {date, actual, estimate}
      local value = transactionsFor[apn]
      if trace then 
         print('insertTransactionFor apn, newValue, value',
               apn, newValue, value)
      end
      if value == nil then
         value = {newValue}
      else
         if trace then print(' value before mutated', value) end
         value[#value + 1] = newValue
         if trace then print(' value after mutated', value) end
      end
      transactionsFor[apn] = value
      if trace then
         print(' apn, transactionsFor[apn]', apn, transactionsFor[apn])
         continue()
      end
   end

   local function summarizeTransactionsFor()
     -- count number of times each number of transactions occurs
      local countOccurs = {}
      
      for apn, transactions in pairs(transactionsFor) do
         --print('apn, transactions', apn, transactions)
         local nTransactions = #transactions
         countOccurs[nTransactions] = (countOccurs[nTransactions] or 0) + 1
      end

      log:log('Number of times APNs traded')
      for count, occurs in pairs(countOccurs) do
         log:log('%10d APNs traded %2d times', occurs, count)
      end
   end


   -- return false if record is invalid
   -- return true, actual, estimate if record is valid
   --   where actual = tonumber(actualString)
   --         estimate = tonumber(estimateString)
   function isGoodInputRecord(apn, date, radius, actualString, estimateString)
      local actual = tonumber(actualString)
      local estimate = tonumber(estimateString)
      if apn == nil or
         string.len(apn) ~= 10 or
         string.len(date) ~= 8 or
         actualString == nil or
         actual == nil or
         estimateString == nil or
         estimate == nil then
         return false
      else
         return true, actual, estimate
      end
   end

   -- read all the usable input data into transactionsFor
   -- only read 1000 if option -test 1 was specified
   for line in input:lines('*l') do
      countInput = countInput + 1
      if options.test == 1 and countInput > 1000 then break end
      local apn, date, radius, actualString, estimateString = 
         string.gmatch(line, '(%d+),(%d+),(%d+),(%d+[%.%d+]*),(%d+[%.%d+]*)')()
      local ok, actual, estimate = 
         isGoodInputRecord(apn, date, radius, actualString, estimateString)
      if ok then
         local year = self:_date2Year(date)
         if yearFirst <= year and year <= 2009 then
            insertTransactionFor(apn, date, actual, estimate)
         else
            countSkippedDate = countSkippedDate + 1
         end
      else
         countSkippedFormat = countSkippedFormat + 1
      end
   end

   -- insert the usable data into the incomplete matrix
   for apn, transactions in pairs(transactionsFor) do
      for transactionNumber, values in ipairs(transactions) do
         --print('transactionNumber, values', transactionNumber, values)
         local date = values[1]
         local actual = values[2]
         local estimate = values[3]
         local added = im:add(apnIndex:apn2Index(apn),     -- rowIndex
                              dateIndex:date2Index(date),  -- colIndex
                              actual - estimate,           -- error
                              false)                       -- verbose
         if added then
            countUsed = countUsed + 1
         else
            countSkippedSameElement = countSkippedSameElement + 1
         end
      end
   end

   summarizeTransactionsFor()

   print(string.format('readEstimates cpu %f\n', os.clock() - start))
   log:log('Read %d data records from incomplete estimates file', countInput)
   log:log(' Used %d estimates from it', countUsed)
   log:log(' Skipped %d records in it because of date', countSkippedDate)
   log:log(' Skipped %d records in it because of format', countSkippedFormat)
   log:log(' Skipped %d records in it because in same row and col',
           countSkippedSameElement)

   return im
end -- _makeIncompleteMatrix

function CompleteMatrix:_makePaths(directories, options)
   -- return table containing paths to input files with these fields
   -- .apns
   -- .dates
   -- .features 
   -- .prices

   assert(directories)
   assert(options)

   local paths = {}

   if options.algo == 'knn' or options.algo == 'kwavg' then
      paths.incompleteEstimates = 
         directories.incompleteEstimates .. 'estimates-mc.csv' 
   elseif options.algo == 'llr' then
      error('llr not yet implemented')
   else
      error('bad options.algo=' .. tostring(options.algo))
   end

   return paths
end -- _makePaths

function CompleteMatrix:_setupDirectories(options, programName)
   --  establish paths to directories and files
   -- ARGS
   -- cmd: CmdLine object used to parse args
   -- options: table of parsed command line parameters
   -- RETURNS table of directories with these fields
   -- .analysis
   -- .incompleteEstimates: string, path to incomplete matrix estimates
   -- .features
   -- .results
   
   assert(options)
   assert(programName)

   local programName = 'complete-matrix-lua'
   local dirObs = options.dataDir .. 'generated-v4/obs' .. options.obs .. '/'
   local dirAnalysis = dirObs .. 'analysis/'
   local dirFeatures = dirObs .. 'features/'
   
   -- the name of the directory with Roy's estimates depends on the algorithm
   local dirIncompleteEstimates
   if options.algo == 'knn' or options.algo == 'kwavg' then
      dirIncompleteEstimates = 
         dirAnalysis .. 
         string.format(
           'create-estimates-lua,algo=%s,obs=%s,radius=%s,which=mc/',
           options.algo, options.obs, options.radius)
   elseif options.algo == 'llr' then
      error('llr not yet implemented')
   else
      error('logic')
   end

   local dirResults = 
      dirAnalysis .. 
      createResultsDirectoryName(programName,
                                 options,
                                 self.optionDefaults) .. '/'
                                                 
   local directories = {}
   directories.analysis = dirAnalysis
   directories.incompleteEstimates = dirIncompleteEstimates
   directories.features = dirFeatures
   directories.results = dirResults

   return directories
end -- _setupDirectories

function CompleteMatrix:_startLogging(dirResults)
   -- create log object and results directory; start logging
   -- ARG
   -- dirResults: string, path to directory
   -- RETURN
   -- log: instance of Log

   assert(dirResults)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      print('results directory not created', command)
      os.exit(false) -- exit with return status EXIT_FAILURE
   end
   
   -- create log file
   pathLogFile = dirResults .. 'log.txt'
   local log = Log(pathLogFile)
   log:log('log started on ' .. os.date())
   
   return log
end -- _startLogging

function CompleteMatrix:_optionError(msg)
   -- report an error in an option
   -- print all the options available

   print('AN ERROR WAS FOUND IN AN OPTION')
   print(msg)

   print('\nAvailable options, defaults, and explanations are')
   local sortedKeys = sortedKeys(options)
   for i = 1,#sortedKeys do
      local name = sortedKeys[i]
      local default = self.optionDefaults[name]
      local explanation = self.optionExplanations[name]
      print(string.format('%17s %-12s %s',
                          name, tostring(default), explanation))
   end
   error('invalid option: ' .. msg)
end

function CompleteMatrix:_validateOptions(options)
   -- validate options that were supplied and set default values for those not
   -- supplied
   -- validate that no extra options were supplied

   -- check for extra options
   for name in pairs(options) do
      if self.optionDefaults[name] == nil then
         self:_optionError('extra option: ' .. name)
      end
   end

   -- supply defaults for any missing option values
   for name, default in pairs(self.optionDefaults) do
      if options[name] == nil then
         options[name] = default
      end 
   end

   -- validate all the option values
   
   -- check for missing required options

   function missing(name)
      self:_optionError('missing option -' .. name)
   end

   if options.algo == ''     then missing('algo') end
   if options.col == ''      then missing('col') end
   if options.dataDir == ''  then missing('dataDir') end
   if options.obs == ''      then missing('obs') end
   if options.radius == 0    then missing('radius') end
   if options.which == ''    then missing('which') end
   if options.yearFirst == 0 then missing('yearFirst') end

   -- check for allowed parameter values

   if not (options.col == 'month' or options.col == 'quarter') then
      self:_optionError('-col must be "month" or "quarter"')
   end

   if options.lambda < 0 then 
      self:_optionError('-lambda must not be negative') 
   end

   if options.rank ~= 0 then
      if options.rank <= 0 then self:_optionError('-rank must be postive') end
      if options.rank ~= math.floor(options.rank) then 
         self:_optionError('-rank must be an integer') 
      end
   end

   if not (options.test == 0 or options.test == 1) then
      self:_optionError('-test must be 0 or 1')
   end

   if not (options.which == 'checkGradient' or 
           options.which == 'complete' or 
           options.which == 'hpCg' or
           options.which == 'hpLbfgs' or 
           options.which == 'hpSgd' or 
           options.which == 'rankSearch' or
           options.which == 'time') then
      self:_optionError('-which must be in ' .. 
                        '{checkGradient,complete,' .. 
                        'hpCg,hpLbfgs,hpSgd,rankSearch,time}')
   end

   if not (1984 <= options.yearFirst and options.yearFirst <= 2009) then
      self:_optionError('-yearFirst must be in [1984,2009]')
   end

   if options.which == 'complete' then
      if options.lambda == 0 then missing('lambda') end
      if options.radius == 0 then missing('radius') end
      if options.radius < 1 then 
         self:_optionError('radius must be positive') 
      end
      if not (options.write == 0 or
              options.write == 1) then
         self:_optionError('write must be 0 or 1')
      end

   elseif options.which == 'hpCg'    or 
          options.which == 'hpLbfgs' or
          options.which == 'hpSgd'   then
      if options.lambda == 0 then missing('lambda') end
      if options.radius == 0 then missing('radius') end

   elseif options.which == 'time' then
   end

   return options
end -- _validateOptions
   
function CompleteMatrix:_whichCheckGradient(incompleteMatrix)
   -- check that the gradient from IncompleteMatrix is correct
   -- NOTE: not updates after last major change, so probably broken
   -- NOTE: takes a very long time to run
   print('Checking gradient')
   local rank = 5
   incompleteMatrix:_initializeWeights(rank)
   print('check weights[1][1]', incompleteMatrix.weights[1][1])
   print('check weights:size()', incompleteMatrix.weights:size())
   local weightsNRows = incompleteMatrix.weights:size(1)
   local weightsNCols = incompleteMatrix.weights:size(2)
   local weightsNElements = weightsNRows * weightsNCols

   local nCalls = 0
   local function opfunc(weights)
      local lambda = 0
      local value, gradient = 
         incompleteMatrix:_opFunc(weights:resize(weightsNRows,
                                                 weightsNCols), 
                                     lambda, 
                                     'all')
      nCalls = nCalls + 1
      print(string.format(' whichCheckGradient %d/%d opfunc value', 
                          nCalls, weightsNRows + weightsNCols, value))
      return value, gradient
   end

   local epsilon = 1e-5
   local d, dy, dh = 
      checkGradient(opfunc,
                    incompleteMatrix.weights:resize(weightsNElements),
                    epsilon)

   -- d is supposed to be small, but how small is reasonable?
   print('d', d)
   assert(d < 1, 'checkGradient returned discouraging result')

end -- _whichCheckGradient

function CompleteMatrix:_whichComplete(dirResults, 
                                       im, 
                                       options,
                                       apnIndex,
                                       dateIndex,
                                       log)
   -- complete the matrix:
   -- 1. Find the optimal weights using L-BFGS (shown to be fastest) 
   --    then SGD (to refine)
   -- 2. Use weights to estimate the complete matrix
   -- 3. Write the complete matrix to all-estimates-mc.csv
   -- 4. Maintain a cache of the L-BFGS results in lbfgs-cache.serialized

   local v = makeVerbose(true, 'CompleteMatrix:whichComplete')

   v('dirResults', dirResults)
   v('im', im)
   v('options', options)
   v('apnIndex', apnIndex)
   v('dateIndex', dateIndex)
   v('log', log)

   affirm.isString(dirResults, 'dirResults')
   affirm.isIncompleteMatrix(im, 'im')
   affirm.isTable(options, 'options')
   assert(torch.typename(apnIndex) == 'ApnIndex')
   assert(torch.typename(dateIndex) == 'DateIndex')
   assert(torch.typename(log) == 'Log')

   -- check on options that we actually use
   affirm.isIntegerPositive(options.rank, 'options.rank')
   affirm.isNumberPositive(options.lambda, 'options.lambda')
   affirm.isInteger(options.write, 'options.write')
   assert(options.write == 0 or
          options.write == 1)
   affirm.isInteger(options.test, 'options.test')
   assert(options.test == 0 or
          options.test == 1)
   affirm.isNumber(options.seed, 'options.seed')


   log:log('args')
   log:log(' rank %d', options.rank)
   log:log(' lambda %g', options.lambda)

   -- build Completion instance
   setRandomSeeds(options.seed)
   local c = Completion(im, options.lambda, options.rank)

   -- find the best weights using L-BFGS
   -- setup the optim state table
   local state = {}
   if options.test == 1 then
      state.maxIter = 2
   end

   local points = 'all'

   print('calling L-BFGS')
   local xStar, lossTable = c:callOptimLbfgs(c:getWeights(),
                                             state,
                                             points)
   c:setWeights(xStar)

   log:log('L-BFGS results')
   log:log(' xStar size %d', xStar:size(1))
   local finalLoss = c:loss(xStar)
   log:log(' loss at xStar on model %f', finalLoss)
   log:log(' lossTable')
   for i, loss in ipairs(lossTable) do
      log:log('   %d = %f', i, loss)
   end
   v('state', state)
   log:log(' L-BFGS state selected entries')
   for key, value in pairs(state) do
      if type(value) ~= 'table' and
         type(value) ~= 'userdata'
      then
         log:log('   %s = %s', key, value)
      end
   end

   if options.write == 0 then
      log:log('completed matrix not written because options.write = %d',
              options.write)
      return
   end

   -- build the completed matrix
   print('starting to complete the matrix')
   local completed = c:complete()

   -- write the completed matrix
   local pathResultsFile = dirResults .. 'all-estimates-mc.csv'
   log:log('%-30s %s', 'pathResultsFile', pathResultsFile)

   local resultsFile = io.open(pathResultsFile, 'w')
   assert(resultsFile, pathResultsFile)

   resultsFile:write('apn,date,estimatedError\n')
   
   log:log('about to write %d rows and % columns',
           completed:size(1), completed:size(2))

   for rowIndex = 1, completed:size(1) do
      if rowIndex % 10000 == 0 then
         print('writing rowIndex', rowIndex)
      end
      for colIndex = 1, completed:size(2) do
         local line = string.format('%s,%s,%s\n',
                                    apnIndex:index2Apn(rowIndex),
                                    dateIndex:index2Date(colIndex),
                                    completed[rowIndex][colIndex])
         resultsFile:write(line)
      end
   end
   resultsFile:close()
   log:log('closed the results file')
   
   if true then return end

   -- OLD CODE FOR _whichCOmplete BELOW ME

   -----------------------------------------------------------------------------
   -- set all hyperparameters for L-BFGS and SGD
   -----------------------------------------------------------------------------

   local alwaysSkipCache = false    -- for debugging

   -- set the hypeparameters for the L-BFGS method
   -- when L-BFGS runs, its add a bunch of fields but does not change
   -- the fields set just below
   local lbfgsState = {}
   lbfgsState.learningRate = 1  -- tested as good
   lbfgsState.maxIter = 20      -- get close to answer

   log:log('L-BFGS state')
   log:log(' learningRate %f', lbfgsState.learningRate)
   log:log(' maxIter      %d', lbfgsState.maxIter)

   --lbfgsState.maxIter = 1       -- for TESTING
   --log:log('STUB testing parameters')

   -- set the hyperparameters for the SGD method
   -- when SGD runs, it adds fields, but doesn't change these
   local sgdState = {}
   -- too big were: 1, 1e-1, 1e-2, 1e-3, 1e-4, 1e-5
   sgdState.learningRate = 1e-5
   sgdState.learningRateDecay = 0
   
   log:log('SGD state')
   log:log(' learningRate %g', sgdState.learningRate)
   log:log(' learningRateDecay %g', sgdState.learningRateDecay)

   -- set number of iterations for SGD
   local sgdIterations = 100  -- for now
   log:log('STUB PARAMETERS: TOSS RESULTS')

   -----------------------------------------------------------------------------
   -- define local functions
   -----------------------------------------------------------------------------

   local function runLbfgs()
      -- return a Completion object with weights from the L-BFGS method
      local tc = TimerCpu()
      local lbfgsPoints = 'all'
      local c = Completion(im:clone(), lambda, rank)
      v('starting lbfgs with state', lbfgsState)
      local xStar, lbfgsLossTable = c:callOptimLbfgs(c:getWeights(),
                                                     lbfgsState, 
                                                     lbfgsPoints)
      c:setWeights(xStar)           -- save the weights
      c.lbfgsState = lbfgsState     -- save hyperparameters and L-BFGS state

      local finalLoss = c:loss(xStar)
      log:log('loss at end of L-BFGS %f', finalLoss)
      v('lbfgs xStar size', xStar:size())
      v('lbfgs lossTable', lbfgsLossTable)
      v('lbfgs loss', c:loss(xStar))
      v('lbfgs elapsed CPU seconds', tc:cumSeconds())
     
      v('c with lbfgs weights', c)
      v('c.lbfgsState', c.lbfgsState)

      return c
   end -- runLbfgs

   local function getLbfgsCompletion()
      -- return Completion object
      -- either the cached object if it exists and corresponds to args and hps
      -- or a brand new object
      setRandomSeeds()  -- for replicability
      local lbfgsCachePath = dirResults .. 'lbfgs-cache.serialized'
      if (not alwaysSkipCache) and
         paths.filep(lbfgsCachePath) then
         -- the cache exists
         -- is it consistent with my args?
         local cachedCompletion = Completion.deserialize(lbfgsCachePath)
         assert(cachedCompletion)

         v('CACHE FILE READ FROM DISK')
         v('cachedCompletion', cachedCompletion)
         v('cachedCompletion.im', cachedCompletion.im)
         v('cachedCompletion.lbfgsState', cachedCompletion.lbfgsState)
         
         -- check all fields except the learned weights (c.weights)
         -- NOTE: a bug in Torch's serialization code leads to writing only
         -- 6 digits of precision in the serialized file. Hence the pessimistic
         -- tolerance for the equality check below
         local equalityTolerance = 1e-5
         
         if false then
            -- code used to debug the if stmt condition just below
            local c1 = rank == cachedCompletion.rank
            local c2 = lambda == cachedCompletion.lambda
            local c3 = lbfgsState.learningRate == 
               cachedCompletion.lbfgsState.learningRate
            local c4 = lbfgsState.maxIter == cachedCompletion.lbfgsState.maxIter
            local c5 = im:equals(cachedCompletion.im, equalityTolerance)
            
            v('condition', c1, c2, c3, c4, c5)
         end
         
         if rank == cachedCompletion.rank and
            lambda == cachedCompletion.lambda and
            lbfgsState.learningRate == 
               cachedCompletion.lbfgsState.learningRate and
            lbfgsState.maxIter == cachedCompletion.lbfgsState.maxIter and
            im:equals(cachedCompletion.im, equalityTolerance)
         then 
            -- disk cache is consistent with args and L-BFGS hyperparameters
            v('used cached Completion object created by previous L-BFGS run')
            return cachedCompletion
         end
      end
      v('RUNNING L-BFGS ANEW')
      local completion = runLbfgs()
      Completion.serialize(lbfgsCachePath, completion)
      return completion
   end -- getLbfgsCompletion

   local function runSgd(c)
      -- run SGD starting with the Completion c using random samples
      -- return a Completion object with weights updated from running SGD 
      assert(c)
      local tc = TimerCpu()
      v('sgd initial state', sgdState)
      sgdPoints = 'random'
      v('sgdIterations', sgdIteration)
      xStar = c:getWeights()
      lossTable = {}
      for i = 1, sgdIterations do
         local sgdLossTable
         xStar, sgdLossTable = c:callOptimSgd(xStar,
                                              sgdState,
                                              sgdPoints)
         lossTable[#lossTable + 1] = sgdLossTable[1]
         
         --v('sgd i', i)
      end
      c:setWeights(xStar)
      c.sgdState = stgState
      
      log:log('loss table from SGD')
      for i = 1, #lossTable do
         log:log(' iteration %d; loss %.15f', i, lossTable[i])
      end

      v('sgd final loss', c:loss(xStar))
      v('sgd elapsed CPU seconds', tc:cumSeconds())
      
      return c
   end -- runSgd

   -- complete the matrix by running SGD on results from L-BFGS
   local c = getLbfgsCompletion()
   v('c after L-BFGS', c)
   c = runSgd(c)
   v('c after SGD', c)
   log:log('loss at end of SGD %f', c:loss(c:getWeights()))
   

   -- Write each estimated error to the results CSV file
   if not write then
      log:log('COMPLETED MATRIX NOT WRITTEN')
      return
   end

   log:log('starting to complete the matrix')
   local completed = c:complete()

   local pathResultsFile = dirResults .. 'all-estimates-mc.csv'
   log:log('%-30s %s', 'pathResultsFile', pathResultsFile)

   local resultsFile = io.open(pathResultsFile, 'w')
   assert(resultsFile, pathResultsFile)

   resultsFile:write('apn,date,estimatedError\n')
   
   log:log('about to write %d rows and % columns',
           completed:size(1), completed:size(2))

   for rowIndex = 1, completed:size(1) do
      if rowIndex % 10000 == 0 then
         print('writing rowIndex', rowIndex)
      end
      for colIndex = 1, completed:size(2) do
         local line = string.format('%s,%s,%s\n',
                                    apnIndex:index2Apn(rowIndex),
                                    dateIndex:index2Date(colIndex),
                                    completed[rowIndex][colIndex])
         resultsFile:write(line)
      end
   end
   resultsFile:close()
   log:log('closed the results file')
end  -- _whichComplete

function CompleteMatrix:_whichHpCg(dirResults,
                                   im,
                                   lambda,
                                   rank,
                                   log)
   -- find best hyperpameters for optim.cg
   -- criteria:
   -- 1. Convergence at all on the im
   -- 2. Convergence quickly
   local p = makeVerbose(true, 'CompleteMatrix:_whichHpCg')
   p('self', self)
   p('dirResults', dirResults)
   p('im', im)
   p('lambda', lambda)
   p('rank', rank)
   p('log', log)

   -- use random initial weights
   local c = Completion(im, lambda, rank)

   -- hyperparameters for cg
   local state = {} -- start with default hyperparameters from optim.cg
   local points = 'all'

   -- for now, test just default parameters
   local x = c:getWeights()
   p('state', state)
   p('points', points)
   local xNext, lossTable = c:callOptimCg(x, state, points)
   log:log('results for points = %s', points)
   log:log('which hp cg')
   log:log('loss table', lossTable)
end -- _whichHpCg

function CompleteMatrix:_whichHpLbfgs(dirResults,
                                      im,
                                      lambda,
                                      rank,
                                      log)
   -- find best hyperpameters for optim.cg
   -- criteria:
   -- 1. Convergence at all on the im
   -- 2. Convergence quickly
   local v = makeVerbose(true, 'CompleteMatrix:_whichHpLbfgs')
   v('self', self)
   v('dirResults', dirResults)
   v('im', im)
   v('lambda', lambda)
   v('rank', rank)
   v('log', log)

   -- use random initial weights
   local c = Completion(im, lambda, rank)
   
   local function logResults(points, states, xStars, lossTables)
      log:log('results for points = %s', points)
      log:log('which hp lbfgs')
      for i = 1 , #states do
         log:log('experiment index %d', i)
         local state = states[i]
         v('state', state)
         log:log('maxIter %d', state.maxIter)
         log:log('learningRate %f', state.learningRate)
         local lossTable = lossTables[i]
         log:log('loss table')
         for i = 1, #lossTable do
            log:log(' %d = %g', i, lossTable[i])
         end
         log:log(' ')
      end
   end -- printResults

   local points = 'all'

   -- sweep across these choices
   local learningRates = {0.01, 0.1, 1, 10, 100}
   -- override for testing
   --learningRates = {0.01}

   -- accumulate these results
   local states = {}
   local xStars = {}
   local lossTables = {}
   for i = 1, #learningRates do
      -- mostly use default state variables
      local state = {}
      state.maxIter = 25    -- number of iterations from CG test
      state.learningRate = learningRates[i]

      local cc = c:clone()
      local xStar, lossTable = cc:callOptimLbfgs(cc:getWeights(), state, points)

      -- accumulate results
      states[#states + 1] = state
      xStars[#xStars + 1] = xStar
      lossTables[#lossTables + 1] = lossTable

      v('i', i)
      v('lossTable', lossTable)
   end
   
   logResults(points, states, xStars, lossTables)
end -- _whichHpLbfgs

function CompleteMatrix:_whichHpSgd(dirResults,
                                    im,
                                    lambda,
                                    rank,
                                    log)
   -- find best hyperpameters for optim.sgd
   -- criteria:
   -- 1. Convergence at all on the im
   -- 2. Convergence quickly
   local v = makeVerbose(true, 'CompleteMatrix:_whichHpSgd')
   v('self', self)
   v('dirResults', dirResults)
   v('im', im)
   v('lambda', lambda)
   v('rank', rank)
   v('log', log)
   
   -- use random initial weights
   local c = Completion(im, lambda, rank)
   
   local function logResults(points, states, xStars, lossTables)
      log:log('results for points = %s', points)
      log:log('which hp lbfgs')
      for i = 1 , #states do
         log:log('experiment index %d', i)
         local state = states[i]
         v('state', state)
         log:log('learningRate %f', state.learningRate)
         log:log('learningRateDecay %f', state.learningRateDecay)
         log:log('points %s', points)
         local lossTable = lossTables[i]
         log:log('loss table')
         for i = 1, #lossTable do
            log:log(' %d = %g', i, lossTable[i])
         end
         log:log(' ')
      end
   end -- printResults

   local function run(points, learningRates)
      -- hyperparameters for sgd
      local points = points
      
      -- sweep across these choices for SGD
      local learningRateDecays = {1e-1, 1e-2, 1e-3, 1e-4}
      local iterations = 25         -- number of SGD iterations
      -- for testing, override with small test sets
      --learningRates = {1e-6, 1e-5}
      --learningRateDecays = {1e-1}
      learningRateDecays = {0}
      --iterations = 2
      
      
      -- accumulate these results
      local states = {}
      local xStars = {}
      local lossTables = {}
      for i = 1, #learningRates do
         for j = 1, #learningRateDecays do
            -- set hyperparameters for SGD
            local state = {}
            state.learningRate = learningRates[i]
            state.learningRateDecay = learningRateDecays[j]
            
            local cc = c:clone()
            -- run 25 iterations 
            -- to match defaults for optim.cg and optim.lbfgs
            local xStar = cc:getWeights()
            lossTable = {}
            for iter = 1, iterations do
               local xStar, loss = cc:callOptimSgd(xStar, 
                                                state, 
                                                points)
               lossTable[#lossTable + 1] = loss[1]
            end
            states[#states + 1] = state
            xStars[#xStars + 1] = xStar
            lossTables[#lossTables + 1] = lossTable
            
            v('i,j', i, j)
            v('state.learningRate', state.learningRate)
            v('state.learningRateDecay', state.learningRateDecay)
            v('state', state)
            v('lossTable', lossTable)
         end
      end
      logResults(points, states, xStars, lossTables)
   end -- run

   run('all',  {1e-6, 1e-5, 1e-4, 1e-3, 1e-2}) -- all points
   run('random', {1e-3, 1e-2, 1e-1, 1, 10}) -- random points
   print('STUB')
end -- _whichHpSgd

function CompleteMatrix:_whichRankSearch(directories,
                                         im,
                                         options,
                                         log)
   -- compare Losses for rank = 1, 2, ..., 10
   -- NOTE: as the rank increases, there are more parameters, so that the
   --       loss always decreases. Hence, need to account for the increase
   --       in parameters. The approach here is to use cross validation
   local v = makeVerbose(true, 'CompleteMatrix:_whichRankSearch')

   affirm.isTable(directories, 'directories')
   affirm.isIncompleteMatrix(im, 'im')
   affirm.isTable(options, 'options')
   affirm.isLog(log, 'log')

   v('im', im)

   -- type and value check each option actually used
   affirm.isNumberPositive(options.lambda, 'options.lambda')
   affirm.isNumber(options.seed, 'options.seed')

   local function cvLoss(rank, selected)
      -- train model of given rank on the selected obs in im
      -- determine loss from this model on the non-selected obs in im

      -- split im into one part with selected observations, the other without
      v('starting to split; rank', rank)
      print('im getNElements', im:getNElements())
      -- the split process does not guarantee that the training and testing
      -- IncompleteMatrices will have the same number of rows and columns.
      -- Hence construct with number of rows and columns specified.
      local nRows = im:getNRows()
      local nCols = im:getNColumns()
      local trainingIm = IncompleteMatrix(nRows, nCols)
      local testingIm = IncompleteMatrix(nRows, nCols)
      local selectedIndex = 0
      for rowIndex, colIndex, value in im:triples() do
         if selectedIndex % 10000 == 0 then
            print('selectedIndex', selectedIndex)
         end
         selectedIndex = selectedIndex + 1
         local s = selected[selectedIndex]
         if s == 1 then
            trainingIm:add(rowIndex, colIndex, value)
         elseif s == 0 then
            testingIm:add(rowIndex, colIndex, value)
         else
            error('bad s = ' .. tostring(s))
         end
      end
      v('trainingIm', trainingIm)
      v('testingIm', testingIm)
      assert(im:getNElements() == 
             trainingIm:getNElements() + testingIm:getNElements())

      -- train model of given rank on selected transactions
      -- use L-BFGS to find optimal weights

      -- start each fold at same random starting point
      setRandomSeeds(options.seed)

      print('building Completion')
      local c = Completion(trainingIm, options.lambda, rank) -- uses the seed
  
      local state = {}            -- L-BFGS args (use all defaults)
      if options.test == 1 then
         state.maxIter = 2
      end
      --state.maxIter = 2  -- for debugging
      --log:log('STUB IGNORE')
      
      local points = 'all'

      print('calling L-BFGS')
      local xStar, lossTable = c:callOptimLbfgs(c:getWeights(),
                                                state, 
                                                points)
      
      log:log('L-BFGS results')
      log:log(' xStar size %d', xStar:size(1))
      local finalLoss = c:loss(xStar)
      log:log(' loss at xStar on model %f', finalLoss)
      log:log(' lossTable')
      for i, loss in ipairs(lossTable) do
         log:log('   %d = %f', i, loss)
      end
      v('state', state)
      log:log(' L-BFGS state selected entries')
      for key, value in pairs(state) do
         if type(value) ~= 'table' and
            type(value) ~= 'userdata'
         then
            log:log('   %s = %s', key, value)
         end
      end

      -- determine loss on un-selected observations using model
      -- must retrain the model, because
      local c2 = Completion(testingIm, options.lambda, rank)
      v('c', c)
      v('c2', c2)
      v('xStar size', xStar:size())
      local estimatedLoss = c2:loss(xStar)
      log:log('Loss on non-training observations %f', estimatedLoss)
      
      return estimatedLoss
   end -- cvLoss

   -- run the cross validation
   local alphas = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10} -- possible ranks
   local nFolds = 5
   local nObservations = im:getNElements()
   local verbose = true
   local alphaStarIndex, losses = crossValidation(alphas,
                                                  cvLoss,
                                                  nFolds,
                                                  nObservations,
                                                  verbose)
   log:log('Average estimated loss for each rank from %d-fold cross validation',
          nFolds)
   for i, loss in ipairs(losses) do
      log:log(' rank %d average estimated loss %f', i, loss)
   end
   log:log('rank with lowest loss is %f', alphas[alphaStarIndex])

end -- _whichRankSearch

function CompleteMatrix:_whichTime(dirResult, 
                                   im, 
                                   rank, 
                                   lambda,
                                   log)
   -- run timing experiment for phase1Time1 CPU seconds
   -- write results to RESULTS/timing.gnuplot
   -- TODO: determine optimal hyperparameters for each method
   -- columns
   --  phase: in {'beginning', 'after 1 hour'}
   --  method: in {'cg', 'lbfgs', 'sgd'}
   --  cpuSec: number of cpu seconds used by phase x method
   --  loss:   loss after that many seconds
   -- ARGS:
   -- dirResult : string, path to directory where the o

   local v = makeVerbose(true, 'CompleteMatrix:_whichTime')
   v('dirResults', dirResult)
   v('im', im.self)
   v('rank', rank)
   v('lambda', lambda)
   v('log', log)

   assert(dirResult)
   assert(im)
   assert(rank)
   assert(lambda)
   assert(log)

   local function runCg()
      -- run on all points
      setRandomSeeds()
      local tc = TimerCpu()
      local state = {}
      local points = 'all'
      local c = Completion(im:clone(), lambda, rank)
      print('cg state') print(state)
      local xStar, lossTable = c:callOptimCg(c:getWeights(), state, points)
      print('cg loss table') print(lossTable)
      local elapsedSeconds = tc:cumSeconds()
      print('elapsed seconds = ', elapsedSeconds)
      return elapsedSeconds, lossTable
   end -- runCg

   local function runLbfgs()
      -- run on all points
      setRandomSeeds()
      local tc = TimerCpu()
      local state = {}
      state.learningRate = 1 -- from which hp lbfgs
      local points = 'all'
      local c = Completion(im:clone(), lambda, rank)
      print('lbfgs state') print(state)
      local xStar, lossTable = c:callOptimLbfgs(c:getWeights(), state, points)
      print('lbfgs loss table') print(lossTable)
      local elapsedSeconds = tc:cumSeconds()
      print('elapsed seconds = ', elapsedSeconds)
      return elapsedSeconds, lossTable
   end -- runLbfgs

   local function runSgd()
      setRandomSeeds()
      -- run on a random sample
      local tc = TimerCpu()
      local learningRate = 1e-4   -- from which hp sgd
      local points = 'random'
      local c = Completion(im:clone(), lambda, rank)
      print('sgd learningRate', learningRate)

      local tc = TimerCpu()
      -- the stochastic gradient is still slow to compute
      -- because the loss function must examine every known point
      local iterations = 20
      local lossTable = {}
      for i = 1, iterations do
         local state = {}
         state.learningRate = learningRate
         
         local xStar, loss = c:callOptimSgd(c:getWeights(), state, points)
         lossTable[#lossTable + 1] = loss[1]
         --v('i', i)
         --v('CPU seconds per iteration', tc:cumSeconds() / i)
      end
      print('sgd loss table') print(lossTable)
      local elapsedSeconds = tc:cumSeconds()
      print('elapsed seconds = ', elapsedSeconds)
      return elapsedSeconds, lossTable
   end -- runSGD
      
   local function logResults(name, elapsedSeconds, lossTable)
      assert(name) 
      assert(elapsedSeconds)
      assert(lossTable)

      log:log(' ')
      log:log('Results for %s', name)
      log:log('Produced the following loss table in %f CPU seconds',
              elapsedSeconds)
      for i = 1, #lossTable do
         log:log(' %d = %f', i, lossTable[i])
      end
   end -- logResults

   logResults('cg', runCg())
   logResults('lbfgs', runLbfgs())
   logResults('sgd', runSgd())

   if true then
      return
   end

end -- _whichTime

