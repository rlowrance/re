-- hp-search-kwavg.lua
-- Conduct cross validation study 
-- to find best hyperparemter lambda for kwavg algo

require 'all'

-------------------------------------------------------------------------------
-- FUNCTIONS
-------------------------------------------------------------------------------

local function makeAlphas(options)
   if options.obs == '1A' then
      -- initial exploration for nearest neighbor window
      -- two parameters: k and regularizer
      -- k > nDims
      -- there are 63 dimensions in the features

      -- 1. try lowest possibly k
      -- results: 0 coverage
      alphas = {{64, 1e-6}} -- start with lowest k

      -- 2. Try some others
      -- all have NaN avg loss
      local reg = 1e-6
      alphas = {{70, reg}, {80, reg}, {90, reg}}

      -- 3. Try something that has good chance of working
      -- Hyp: if all Nan, then try removing the redundant features
      -- When run in test mode, every result is singular
      alphas = {{120, 1e-1}}  -- mostly NaN results

      alphas = {{180, 1e-03}}  -- 10 consecutive not OKs
      alphas = {{20, 1e-03}}   -- k too small (must be at least 56)
      alphas = {{60, 1e-03}}   -- 10 consecutive not OKs
      alphas = {{70, 1e-03}}   -- 

      -- 4.DO NOT REMOVE REDUNDANT 1-of-K columns
      alphas = {{70, 1e-03}}   -- singular
      alphas = {{70, 0}}       -- disable the regularizer; singular
      -- NOTE: a zero regularizer leads to a singular result (by design)
      alphas = {{70, 1e-3}}
      
      
   else
      error('invalid options.obs = ' .. tostring(options.obs))
   end
   return alphas
end -- makeAlphas


local function modelFit(alpha, removedFold, kappa, 
                        trainingXs, trainingYs, 
                        modelState, options)
   local v, isVerbose = makeVerbose(false, 'makeFittedModel')

   verify(v,
          isVerbose,
          {{alpha, 'alpha', 'isTable'},  -- {k, regularizer}
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
      -- all the training observations. So build a new cache.
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
   local fittedModel = NnwSmootherLlr(trainingXs,
                                      trainingYs, 
                                      selected,
                                      nncache,
                                      kernelName)
   
   modelState.nConsecutiveNotOk = 0
   return fittedModel
end -- modelFit

local function modelUse(alpha, model, i, modelState, options)
   -- return ok, estimate
   -- alpha is the number of neighbors
   
   local v, isVerbose = makeVerbose(false, 'modelUse')
   verify(v, isVerbose,
          {{alpha, 'alpha', 'isTable'},
           {model, 'model', 'isTable'},
           {i, 'i', 'isIntegerPositive'},
           {modelState, 'modelState', 'isTable'},
           {options, 'options', 'isTable'}})

   collectgarbage()  -- avoid a bug in torch
   
   assert(modelState.selected[i] == 0,
          'cross validate with non-training observations')
   
   local params = {}
   params.k = alpha[1]
   params.regularizer = alpha[2]
   v('params', params)
   local ok, estimate = model:estimate(i, params)
   if not ok then
      modelState.nConsecutiveNotOk = modelState.nConsecutiveNotOk + 1
      if options.maxConsecutiveNotOk ~= 0 then
	 assert(modelState.nConsecutiveNotOk < options.maxConsecutiveNotOk,
		string.format('hit maxConsecutiveNotOK limit of %d', 
			      options.maxConsecutiveNotOk))
      else
	 modelState.nConsecutiveNotOk = 0
      end
   end
   return ok, estimate
end -- modelFit

local function resultsLog(results, coverage, options)
   -- write results to a log
   -- ARGS
   -- log: Log instance
   -- results : table 
   --            key = k
   --            value = avg loss on validation set

   local log = options.log
   affirm.isLog(log, 'log')
   affirm.isTable(results, 'results')
   affirm.isTable(coverage, 'coverage')
   affirm.isTable(options, 'options')

   local function lossName(options)
      if options.cvLoss == 'abs' then return 'absolute'
      elseif options.cvLoss == 'squared' then return 'squared'
      else error('bad options.cvLoss')
      end
   end -- lossName

   log:log('avg %s loss on validation set, coverage',
           lossName(options))
   for _, key in ipairs(sortedKeys(results)) do
      print('results key', key)
      print('results value', results[key])
      if results[key] ~= results[key] then
         log:log('k = %d reg =%f average loss = NaN, coverage = %6.4f',
                 key[1], key[2], coverage[key])
      else
         log:log('k = %d reg = %f' .. 
                 ' average loss = %6.0f coverage = %6.4f',
                 key[1], key[2], results[key], coverage[key])
      end
   end
end -- resultsLog

local function resultsReport(loss, coverage, nFolds, options)
   -- write results to a report file
   -- ARGS
   -- dirOutput : string, path to directory of all outputs
   -- options   : table of options
   -- loss   : table 
   --               key = lambda
   --               value = average absolute loss on validation set
   -- coverage  : table
   --               key = lambda
   --               value = fraction of observations for which an estimate
   --                       was available
   -- nFolds    : integer > 0, number of folds

   local dirOutput = options.dirOutput
   local v = makeVerbose(false, 'writeReport')
   affirm.isString(dirOutput, 'dirOutput')
   affirm.isTable(options, 'options')
   affirm.isTable(loss, 'loss')

   local function get(k, fold)
      -- return loss[{k,fold}]
      for key, loss in pairs(loss) do
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

   local file, err = io.open(dirOutput .. filename, 'w')
   if file == nil then
      error('unable to open report file; err = ' .. err)
   end

   if options.test == 1 then
      file:write('TESTING: IGNORE\n')
   end
   file:write('CROSS VALIDATION RESULTS FOR LLR\n')
   header2 = 'Avg %s Error and Coverage on Validation Set by Lambda\n'
   if options.cvLoss == 'abs' then
      file:write(string.format(header2, 'Absolute'))
   elseif options.cvLoss == 'squared' then
      file:write(string.format(header2, 'Squared'))
   end
  
   file:write('Observation set ' .. options.obs .. '\n')
   file:write(nFolds .. ' folds\n')
   file:write('\n')
   
   --file:write('  k     Avg Loss\n')
   file:write('  k Regularizer Avg Loss    Coverage\n')

   for _, key in ipairs(sortedKeys(loss)) do
      local k = key[1]
      local reg = key[2]
      file:write(string.format('%3d %11g    %6.0f   %9.7f\n', 
                               k, reg, loss[key], coverage[key]))
   end

   file:close()
end -- resultsReport

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

local programName = 'hp-search-llr'

local dropRedundant = true

local hps = HpSearch(not dropRedundant,
                     makeAlphas, 
                     modelFit, 
                     modelUse,
                     programName, 
                     resultsLog, 
                     resultsReport)
hps:run()
