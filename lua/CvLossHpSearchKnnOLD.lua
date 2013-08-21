-- CvLossHpSearchKnn.lua
-- cross validation loss class for hp-search-knn

-- API overview
if false then
   cl = CvLossHpSearchKnn(data, maxK)
   -- data.features == 2D Tensor
   -- data.prices   == 1D Tensor

   -- train model on selected observations
   -- return loss from running trained model on other observations
   lossOnValidationSet = cl:run(k, fold, selectedForTraining)

   validationLosses = cl:results()  -- return table of loss on validation sets
   -- key = {k, fold}
   -- value = loss on validation set
end

--require 'Log'
--require 'makeVerbose'

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('CvLossHpSearchKnn')

function CvLossHpSearchKnn:__init(data, maxK)
  
   local v = makeVerbose(false, 'CvLossHpSearchKnn:__init')
   affirm.isTable(data, 'data')
   affirm.isIntegerPositive(maxK, 'maxK')

   v('data', data)
   v('maxK', maxK)

   self.features = data.features
   self.prices = data.prices
   self.maxK = maxK

   -- enable reuse of the Knn object
   self.lastFoldNumber = nil
   self.knn = nil     -- keep in self, so that cache can be reused
   self.nValidationSet = nil

   -- keep track of the validation observations
   self.validationFeatures = nil
   self.validationPrices = nil

   -- keep track of results so can write nice report
   self.results = {} -- key = {k, fold} value == loss
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function CvLossHpSearchKnn:getResults()
   
   return self.results
end -- results

function CvLossHpSearchKnn:run(k, fold, selectedForTraining, log)
   -- 1. train on selected observations to find the optimal weights
   -- 2. use optimal weights to return the loss on the non-selected observations

   -- optimized to be called repeatably:
   -- for fold in foldRange
   --    for k in kRange
   --       cvLossHpSearchKnn:run(k, fold, selectedForTraining)
   
   -- ARGS
   -- k                   : integer > 0, number of neighbors
   -- fold                : integer > 0, fold number
   -- selectedForTraining : 1D Tensor of 0/1 values
   --                       1 indicates observation is in the training set
   --                       0 indicates observation is in the validation set
   -- log                 : Log instance
   -- RETURNS
   -- avgSquaredError     : number
   --                       average squared loss on each element of the
   --                       validation set

   local v, verbose = makeVerbose(false, 'CvLossHpSearchKnn:run')
   local debug = true

   affirm.isIntegerPositive(k, 'k')
   affirm.isIntegerPositive(fold, 'fold')
   affirm.isTensor1D(selectedForTraining, 'selectedForTraining')
   affirm.isLog(log, 'log')

   local tc = TimerCpu()

   log:log('CvLossHpSearchKnn:run k %g', k)
   log:log('CvLossHpSearchKnn:run fold %d', fold)
   log:log('CvLossHpSearchKnn:run selected size %d', 
           selectedForTraining:size(1))
   log:log('CvLossHpSearchKnn:run number training observations %d',
           torch.sum(selectedForTraining))

   -- build the Knn object or use the previous one
   
   if true or self.lastFoldNumber ~= fold then
      log:log('STUB: always build new Knn object')
      log:log('building new Knn object')
      self.nValidationSet, self.validationFeatures, self.validationPrices = 
         self:_makeValidationSets(selectedForTraining)
      self.knn = Knn(self.validationFeatures,
                     self.validationPrices,
                     self.maxK)  
      self.lastFoldNumber = fold
      log:log('CvLossHpSearchKnn:run number of validation observations %d',
              self.nValidationSet)
   end

   -- 1. train on selected observations to find the optimal weights
   -- Nothing to do, as Knn as no weights

   -- 2. use optimal weights to return the loss on the non-selected observations
   -- The loss is the average squared loss on the validation set

   -- args to knn:smooth
   local k = k
   local useQueryPoint = false

   -- loop-related vars
   local tc = TimerCpu()
   local totalSquaredError = 0
   local countOkEstimate = 0
   for queryIndex = 1, self.nValidationSet do
      -- we are looking at only the validation set
      -- so every queryIndex is valid
      collectgarbage()  -- avoid bug in torch
      if queryIndex % 10000 == 0 then
         print('queryIndex', queryIndex, 
               'cpuSec per query', tc:cumSeconds() / queryIndex)
      end
      v('self.knn', self.knn)
      local ok, estimate, cacheHit = self.knn:smooth(queryIndex,
                                                     k,
                                                     useQueryPoint)
      if ok then
         countOkEstimate = countOkEstimate + 1
         local price = self.validationPrices[queryIndex]
         local loss = price - estimate
         v('queryIndex,price,est,loss', 
           queryIndex, price, estimate, loss)
         totalSquaredError = totalSquaredError + loss * loss
         -- verify that we used the cache
      else
         error('estimate not ok; msg = ' .. estimate)
      end
   end -- queryIndex loop

   v('countOkEstimate', countOkEstimate)
   if countOkEstimate == 0 then
      error('countOkEstimate is 0')
   end

   local avgSquaredError = totalSquaredError / countOkEstimate
   v('k,fold,avgSquaredError', k, fold, avgSquaredError)

   local lossOnValidationSet = avgSquaredError
   local elapsedCpu = tc:cumSeconds()
   self.results[{k, fold}] = avgSquaredError
   if verbose then
      for key, value in pairs(self.results) do
         local k = key[1]
         local fold = key[2]
         v('k,fold,avg squared error on validation set', k, fold, value)
      end
   end
   
   log:log('k %d fold %d loss %f cpuSeconds %f',
           k, fold, avgSquaredError, elapsedCpu)
   return avgSquaredError
end -- run


--------------------------------------------------------------------------------
-- PRIVATE METHODS
--------------------------------------------------------------------------------

function CvLossHpSearchKnn:_makeValidationSets(selectedForTraining)
   -- RETURNS validation sets for features and prices
   -- n        : integer, number in validation set
   -- features : 2D Tensor
   -- prices   : 1D Tensor
   local v = makeVerbose(false, 'CvLossHpSearchKnn:_makeValidationSets')
   local debug = false

   affirm.isTensor1D(selectedForTraining, 'selectedForTraining')
   v('selectedForTraining', selectedForTraining)

   local nValidationSet = 
      selectedForTraining:size(1) - torch.sum(selectedForTraining)
   assert(nValidationSet > 0, 'validation set is empty')
   if debug then
      v('self.features', self.features)
      v('self.features:size(2)', self.features:size(2))
   end
   local features = torch.Tensor(nValidationSet, self.features:size(2))
   local prices = torch.Tensor(nValidationSet)

   local validationIndex = 0
   for i = 1, selectedForTraining:size(1) do
      if selectedForTraining[i] == 0 then
         validationIndex = validationIndex + 1
         features[validationIndex] = self.features[i]
         prices[validationIndex] = self.prices[i]
      end
   end
   assert(validationIndex == nValidationSet)
   v('nValidationSet', nValidationSet)
   v('validation set features', features)
   v('validaton set prices', prices)
   return nValidationSet, features, prices
end -- _makeValidationSets


function CvLossHpSearchKnn:wrapup(alphas, dirOutput, log, options)
   -- write results in nice table for inclusion in report
   -- also write to log

   local v = makeVerbose(false, 'CvLossHpSearchKnn:wrapup')
   v('self.results', self.results)
   v('sorted key', sortedKeys(self.results))

   assert(alphas)
   assert(dirOutput)
   assert(log)
   assert(options)

   log:log('summary across k values and fold numbers')

   local ks = {}
   local maxfold = 0
   for _, key in ipairs(sortedKeys(self.results)) do
      local k = math.floor(key)
      local fold = math.floor((key - k) * 10 + 0.001)
      v('key,k,fold', key, k, fold)

      ks[#ks + 1] = k
      maxfold = math.max(fold, maxfold)

      local value = self.results[key]
      local loss = value[1]
      local cpuSecs = value[2]

      log:log(' k %3d fold %1d validationLoss %11g cpuSecs %f',
              k, fold, loss, cpuSecs)
   end

   -- write report to output

   local function get(k, fold)
      local key = k + fold / 10
      v('get: k,fold,key', k, fold, key)
      return self.results[key][1]
   end

   local filename = string.format('hp-search-knn-%s.txt', options.obs)
   local file, err = io.open(dirOutput .. filename, 'w')
   if file == nil then
      error('unable to open report file; err = ' .. err)
   end
   file:write('CROSS VALIDATION RESULTS FOR KNN\n')
   file:write('Losses on Validation Set by Fold and On Average Across Folds\n')
   file:write('Observation set ' .. options.obs .. '\n')
   file:write('\n')
   header = '  k'
   hformat = ' %10s'
   for fold = 1, maxfold do
      header = header .. string.format(hformat, 'fold' .. tostring(fold))
   end
   header = header .. string.format(hformat, 'average')
   file:write(header .. '\n')
   local formatloss = ' %10.4e'
   for _, k in ipairs(alphas) do
      file:write(string.format('%3d', k))
      local sumLosses = 0
      for fold = 1, maxfold do
         local loss = get(k, fold)
         v('k,fold,loss', k, fold, loss)
         file:write(string.format(formatloss, loss))
         sumLosses = sumLosses + loss
      end
      file:write(string.format(formatloss, sumLosses / maxfold))
      file:write('\n')
   end

   file:close()
end -- wrapup

