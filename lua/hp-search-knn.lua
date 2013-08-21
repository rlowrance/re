-- hp-search-knn.lua
-- Conduct a cross validation study to find best hyperparamter k for knn algo

require 'all'

-------------------------------------------------------------------------------
-- FUNCTIONS
-------------------------------------------------------------------------------

local function makeAlphas(options)
   -- return alphas
   if options.obs == '1A' then
      -- 1. Test hypothesis that alpha* = 76: cannot be true
      --    this run shows that the minimizer is below 70
      alphas = {70, 80, 100}   -- stopped before file written

      -- 2. Shows minimizer is in [10, 50]
      alphas = {40, 50}

      -- 3. shows minimizer is in (2, 20)
      alphas = {20, 30}

      -- 4. shows minimizer is in (2,10)
      alphas = {6, 16}

      -- 5. shows 4 is the minimizer
      alphas = {3, 4 , 5, 7, 8, 9, 10}

      -- 6. Comprehensive run for report
      --    Shows minimizer is k*=5
      --    The estimate of the generalization error function is not monotone
      alphas = {1,2,3,4,5,6,7,8,9,10,20,30,40,50,60,70,80,90,100}

   else
      error('need to set alphas for obs other than 1A')
   end
   return alphas
end -- makeAlphas

local function modelFit(alpha, removedFold, kappa, 
                        trainingXs, trainingYs,
                        modelState, options)
   -- return a model fitted to data not in the fold
   local v, isVerbose = makeVerbose(false, 'modelFit')

   verify(v,
          isVerbose,
          {{alpha, 'alpha', 'isIntegerPositive'},
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
      local nShards = 1
      local nnc = Nncachebuilder(trainingXs, nShards)
      local shard = 1
      local cacheFilePathPrefix = string.format('/tmp/%s-test-cache-',
                                                options.programName)
      nnc:createShard(shard, cacheFilePathPrefix)
      Nncachebuilder.mergeShards(nShards, cacheFilePathPrefix)
      cache = Nncache.loadUsingPrefix(cacheFilePathPrefix)
   else
      -- use the pre-built cache
      local cacheFilePathPrefix =
         options.dirOutput .. 'obs' .. options.obs .. '-'
      options.log:log(
         'reading nearest neighbor index cache %s', cacheFilePathPrefix)
      nncache = Nncache.loadUsingPrefix(cacheFilePathPrefix)
   end
   local fittedModel = SmootherAvg(trainingXs,
                                   trainingYs, 
                                   selected,
                                   nncache)
   
   
   return fittedModel
end -- modelFit

local function modelUse(alpha, model, i, modelState, options)
   -- return ok, estimate
   -- alpha is the radius
   
   local v = makeVerbose(false, 'HpSearch::modelUse')
   v('i', i)
   v('modelState', modelState)
   v('modelState.selected[i]', modelState.selected[i])
   collectgarbage()  -- avoid a bug in torch
   
   assert(modelState.selected[i] == 0,
          'cross validate with non-training observations')
   
   local ok, estimate = model:estimate(i, alpha)
   return ok, estimate
end -- modelFit


local function resultsLog(lossTable, coverageTable,  options)
   -- write results to a log
   -- ARGS
   -- results : table 
   --            key = k
   --            value = avg loss on validation set

   local v, isVerbose = makeVerbose(false, 'resultsLog')
   verify(v, isVerbose,
          {{lossTable, 'lossTable', 'isTable'},
           {coverageTable, 'coverageTable', 'isTable'},
           {options, 'options', 'isTable'}})

   -- check that coverage is always 1
   for _, coverage in pairs(coverageTable) do
      if coverage ~= 1 then
         print('coverageTable', coverageTable)
         error('coverage not 1')
      end
   end

   local function lossName(options)
      local v = makeVerbose(false, 'lossName')
      v('options', options)
      if options.cvLoss == 'abs' then return 'absolute'
      elseif options.cvLoss == 'squared' then return 'squared'
      else error('bad options.cvLoss')
      end
   end -- lossName

   for _, key in ipairs(sortedKeys(lossTable)) do
      options.log:log('k %d average %s loss on validation set = %g',
                      key, lossName(options), lossTable[key])
   end
end -- resultsLog


local function resultsReport(lossTable, coverageTable, nFolds, options)
   -- write results to a report file
   -- ARGS
   -- options   : table of options
   -- lossTable   : table 
   --               key = k
   --               value = average absolute loss on validation set

   local v, isVerbose = makeVerbose(false, 'writeReport')
   verify(v, isVerbose,
          {{lossTable, 'lossTable', 'isTable'},
           {coverageTable, 'coverageTable', 'isTable'},
           {nFolds, 'nFolds', 'isIntegerPositive'},
           {options, 'options', 'isTable'}})

   local function get(k, fold)
      -- return lossTable[{k,fold}]
      for key, loss in pairs(lossTable) do
         if key[1] == k and key[2] == fold then return loss end
      end
      error('cannot happen, k,fold=' .. tostring(k) .. ',' .. tostring(fold))
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
   file:write('CROSS VALIDATION RESULTS FOR KNN\n')
   --file:write('Avg Squared Error on Validation Set by K (num neighbors)\n')
   header2 = 'Avg %s Error on Validation Set by K\n'
   if options.cvLoss == 'abs' then
      file:write(string.format(header2, 'Absolute'))
   elseif options.cvLoss == 'squared' then
      file:write(string.format(header2, 'Squared'))
   end
  
   file:write('Observation set ' .. options.obs .. '\n')
   file:write(nFolds .. ' folds\n')
   file:write('\n')
   
   --file:write('  k     Avg Loss\n')
   file:write('  k  Avg Loss\n')

   for _, k in ipairs(sortedKeys(lossTable)) do
      file:write(string.format('%3d    %6.0f\n', k, lossTable[k]))
   end

   file:close()
end -- writeReport

--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

local programName = 'hp-search-knn'

local dropRedundant = true
local hps = HpSearch(not dropRedundant,
                     makeAlphas,
                     modelFit,
                     modelUse,
                     programName,
                     resultsLog,
                     resultsReport)

hps:run()
