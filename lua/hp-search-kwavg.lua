-- hp-search-kwavg.lua
-- Conduct cross validation study 
-- to find best hyperparemter lambda for kwavg algo

require 'all'

-------------------------------------------------------------------------------
-- FUNCTIONS
-------------------------------------------------------------------------------

local function makeAlphas(options)
   if options.obs == '1A' then
      -- lambda = 31 is lowest lambda with 100% coverage
      -- find lambda that equals the best loss from knn ( = 69535)
      -- Lambda that equals best KNN loss is 3.8 + a bit
      alphas = {0.5, 1.0, 2, 3.8, 4, 8, 16, 31}

      -- locate minimizer, which is in (0, 1.0)
      -- shows 0.1 has low loss
      -- shows loss at 3.9 is 69962 (too high)
      -- find better match for KNN than 3.8
      alphas = {0.1, 3.9}

      -- detect if minimizer is below 0.1
      -- test 3.85 as match for knn
      -- shows loss at 0.01 is 8 coverage 0.0115
      alphas = {0.01, 3.85}

      -- try to match knn best result
      alphas = {3.83}

      -- comprehensive run
      -- if options.test == 1, considering only 100% coverage on the 1000 obs
      -- then the minimizer is 30
      alphas = {0.01, 0.1, 1, 3.83, 10, 20, 30, 31, 40, 50, 60, 70, 80}

      -- restart testing given new code
      
      -- alpha is now the number of neighbors
      alphas = {3, 5, 10, 20, 30, 40}

      -- 1. restart testing after massive refactoring
      alphas = {5}

      -- 2. search for minimizer: shows minimizer in (5,20)
      alphas = {10, 20}

      -- 3. search for minimizer; shows minimizer in (7,13)
      alphas = {7, 13, 30}

      -- 4. check all possible minimizers
      alphas = {8, 9, 11, 12}

      -- when re-running, do all alphas
      alphas = {1,5,6,7,8,9,10,20,30}

      -- TO Debug the k=5 problem (not 100% coverage)
      alphas = {5}

   else
      error('need to set alphas for obs other than 1A')
   end
   return alphas
end -- makeAlphas

local function modelFit(alpha, removedFold, kappa, 
                        trainingXs, trainingYs,
                        modelState, options)
   local v, isVerbose = makeVerbose(false, 'modelFit')

   verify(v,
          isVerbose,
          {{alpha, 'alpha', 'isNumberPositive'},
           {removedFold, 'removedFold', 'isIntegerPositive'},
           {kappa, 'kappa', 'isSequence'},
           {trainingXs, 'trainingXs', 'isTensor2D'},
           {trainingYs, 'trainingYs', 'isTensor1D'},
           {modelState, 'modelState', 'isTable'},
           {options, 'options', 'isTable'}})

   v('options', options)
   affirm.isString(options.dirOutput, 'modelState.dirOutput')

   local selected = makeFittedDataSelector(removedFold, kappa)
   modelState.selected = selected
   v('modelState', modelState)

   -- establish cache, needed to construct the smoother
   local nncache
   if options.test == 1 then
      -- We've read only 1000 training observations but the cache is for
      -- all the training observations. So build a new cache
      options.log:log('creating cache for first 1000 observations')
      local nShards = 1
      local nnc = Nncachebuilder(trainingXs, nShards)
      local shard = 1
      local cacheFilePathPrefix = string.format('/tmp/%s-test-cache-',
                                                options.programName)
      nnc:createShard(shard, cacheFilePathPrefix)
      Nncachebuilder.mergeShards(nShards, cacheFilePathPrefix)
      nncache = Nncache.loadUsingPrefix(cacheFilePathPrefix)
   else
      -- use the pre-built cache
      local cacheFilePathPrefix =
         options.dirOutput .. 'obs' .. options.obs .. '-'
      options.log:log(
         'reading nearest neighbor index cache %s', cacheFilePathPrefix)
      nncache = Nncache.loadUsingPrefix(cacheFilePathPrefix)
   end

   -- fit the model on a portion of the training data
   local kernelName = 'epanechnikov quadratic'
   local fittedModel = NnwSmootherKwavg(trainingXs,
                                        trainingYs, 
                                        selected,
                                        nncache,
                                        kernelName)
   
   
   return fittedModel
end -- modelFit

local function modelUse(alpha, model, i, modelState, options)
   -- return ok, estimate
   -- alpha is the number of neighbors
   
   local v = makeVerbose(false, 'modelUse')
   v('i', i)
   v('modelState', modelState)
   v('modelState.selected[i]', modelState.selected[i])

   if options.debug == 4 then
      -- only run for observations where lambda == 0
      if i == 70096 or i == 70097 then
         -- keep going
      else
         return true, 0
      end
   end

   if options.debug == 4 and i > 70097 then
      halt()
   end

   collectgarbage()  -- avoid a bug in torch
   
   assert(modelState.selected[i] == 0,
          'cross validate with non-training observations')
   
   local ok, estimate = model:estimate(i, alpha)
   if not ok and options.debug == 4 then
      print('not ok; i = ', i)
      halt()
   end
   return ok, estimate
end -- modelFit


local function resultsLog(lossTable, coverageTable, options)
   -- write results to a log
   -- ARGS
   -- log: Log instance
   -- results : table 
   --            key = k
   --            value = avg loss on validation set

   local v, isVerbose = makeVerbose(false, 'resultsLog')
   verify(v, isVerbose,
          {{lossTable, 'lossTable', 'isTable'},
           {coverageTable, 'coverageTable', 'isTable'},
           {options, 'options', 'isTable'}})

   local log = options.log

   local function lossName(options)
      if options.cvLoss == 'abs' then return 'absolute'
      elseif options.cvLoss == 'squared' then return 'squared'
      else error('bad options.cvLoss')
      end
   end -- lossName

   log:log('avg %s loss on validation set, coverage',
           lossName(options))
   for _, key in ipairs(sortedKeys(lossTable)) do
      log:log('lambda = %5.2f average loss = %6.0f coverage %6.4f',
              key, lossTable[key], coverageTable[key])
   end
end -- logResults

local function resultsReport(lossTable, coverageTable, nFolds, options)
   -- write results to a report file
   -- ARGS
   -- lossTable     : table 
   --                  key = lambda
   --                  value = average absolute loss on validation set
   -- coverageTable : table
   --                  key = lambda
   --                  value = fraction of observations for which an estimate
   --                          was available
   -- nFolds        : integer > 0, number of folds
   -- options       : table

   local v, isVerbose = makeVerbose(false, 'writeReport')
   verify(v, isVerbose,
          {{lossTable, 'lossTable', 'isTable'},
           {coverageTable, 'coverageTable', 'isTable'},
           {nFolds, 'nFolds', 'isIntegerPositive'},
           {options, 'options', 'isTable'}})

   local log = options.log

   local function get(k, fold)
      -- return loss[{k,fold}]
      for key, loss in pairs(lossTable) do
         if key[1] == k and key[2] == fold then return loss end
      end
      error('cannot happen, lambda,fold=' .. 
            tostring(k) .. 
            ',' .. 
            tostring(fold))
   end -- get

   local filename
   if options.test == 1 then
      filename = string.format('%s-%s-test.txt', 
                               options.programName, options.obs)
   else
      filename = string.format('%s-%s.txt', 
                               options.programName, options.obs)
   end

   local file, err = io.open(options.dirOutput .. filename, 'w')
   if file == nil then
      error('unable to open report file; err = ' .. err)
   end

   if options.test == 1 then
      file:write('TESTING: IGNORE\n')
   end
   file:write('CROSS VALIDATION RESULTS FOR KWAVG\n')
   header2 = 'Avg %s Error and Coverage on Validation Set by Lambda\n'
   if options.cvLoss == 'abs' then
      file:write(string.format(header2, 'Absolute'))
   elseif options.cvLoss == 'squared' then
      file:write(string.format(header2, 'Squared'))
   end
  
   file:write('Observation set ' .. options.obs .. '\n')
   file:write(nFolds .. ' folds\n')
   file:write('\n')
   
   file:write('lambda  Avg Loss    Coverage\n')

   for _, lambda in ipairs(sortedKeys(lossTable)) do
      file:write(string.format('  %5.2f   %6.0f   %9.7f\n', 
                               lambda, 
                               lossTable[lambda], 
                               coverageTable[lambda]))
   end

   file:close()
end -- resultsReport

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

local programName = 'hp-search-kwavg'

local dropRedundant = true

local hps = HpSearch(not dropRedundant,
                     makeAlphas,
                     modelFit,
                     modelUse,
                     programName,
                     resultsLog,
                     resultsReport)

hps:run()
