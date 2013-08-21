-- CvLoss.lua
-- class to determine cross validation loss

-- API overview
if false then
   local function fittedModelFactory(fold, data, kappa, alphas)
   end

   local cl = CvLoss(alphas, fittedModelFactory, options)
   
   local loss = cl:cvLoss(alpha, i, kappa)
end -- API overview

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('CvLoss')

function CvLoss:__init(alphas, data, makeFittedModel, options)
   -- ARGS
   -- alphas      : sequence of alpha values
   --               each alpha designates a model to be cross validated
   -- data        : table of data Tensors
   -- ModelFactor : class (see below)
   -- options     : table of option values
   -- where the API for makeFittedModel is
   -- ARGS
   -- fold   : integer > 0
   -- data   : table
   -- kappa  : sequence
   -- alphas : sequence of alpha values
   -- RETURNS
   -- fittedModel : instance of a model with method where smooth's API is
   --   ok, estimate, cacheHit, sortedIndices =  
   --      smooth(foldObservationIndex, alpha, useQueryPoint)
  
   if false then
      fitted = FittedModelFactory(fold, data, kappa, alphas) -- fit model
      actualPrice = fitted.ys[modelIndex]  -- y value for index in model
      ok, estimatedPrice, usedCache, sortedIndices = 
         fitted:smooth(modelIndex, alpha, useQueryPoint)
   end
  
   local v = makeVerbose(true, 'CvLoss:__init')
   v('alphas', alphas)
   v('data', data)
   v('makeFittedModel', makeFittedModel)
   v('options', options)

   affirm.isSequence(alphas, 'data')
   affirm.isTable(data, 'data')
   affirm.isFunction(makeFittedModel, 'ModelFactory')
   affirm.isTable(options, 'options')

   self._alphas = alphas
   self._data = data
   self._modelFactor = makeFittedModel
   sefl._options = options

   self._fittedModels = {}  -- will be one for each fold
   self._mi = nil
end -- __init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

function CvLoss:cvLoss(alpha, i, kappa)
   -- return loss on observation i (in fold kappa[i])
   -- from model fitted with observations not in fold kappa[i]
   -- define loss as the absolute value of the estimation error
   -- or as the squared error, depending on options.cvLoss
   -- ARGS
   -- alpha    : some object usable as arg to fitModel and useModel
   -- i        : integer > 0, index of global observation number
   -- kappa    : sequence of integer > 0
   --            kappa[i] is the fold number of observation i
   -- fitModel : function (see below)
   -- useModel : function (see below)
   -- options  : table of option values
   
   local v = makeVerbose(false, 'cvLoss')
   v('alpha', alpha)
   v('i', i)
   v('kappa', kappa)

   local tc = TimerCpu()
   collectgarbage()   -- avoid bug in torch7

   assert(alpha ~= nil, 'alpha cannot be nil')
   affirm.isIntegerPositive(i, 'i')
   affirm.isSequence(kappa, 'kappa')

   local fold = kappa[i]
   local model = self._fittedModels[fold]
   if model == nil then
      -- create and fit model to all the data in the fold
      fittedModels[fold] = self._makeFittedModel(fold, 
                                                 self._data, 
                                                 kappa, 
                                                 self._alphas)
   end
   
   if self._mi == nil then
      self._mi = ModelIndex(kappa)
   end

   local modelObsIndex = mi:globalToFold(i)
   v('modelObsIndex', modelObsIndex)

   local actualPrice = model:getY(modelObsIndex)
   local useQueryPoint = true
   local ok, estimatedPrice, usedCache, sortedIndices = 
      model:smooth(modelObsIndex, k, not useQueryPoint)
   if not ok then
      error('no estimate; reason = ' .. estimatedPrice)
   end
   local error = actualPrice - estimatedPrice
   v('kappa', kappa)
   v('i,modelObsIndex', i, modelObsIndex)
   v('actualPrice', actualPrice)
   v('estimatedPrice', estimatedPrice)
   v('usedCache', usedCache)
   v('sortedIndices', sortedIndices)
   if options.debug == 1 then
      local globalQueryIndex = sortedIndices[1]
      local queryApn = trainingData.apns[globalQueryIndex]
      local queryDate = trainingData.dates[globalQueryIndex]
      print('query apn, date    ', queryApn, queryDate)

      local globalNeighborIndex1 = sortedIndices[2]
      local neighbor1Apn = trainingData.apns[globalNeighborIndex1]
      local neighbor1Date = trainingData.dates[globalNeighborIndex1]
      print('neighbor1 apn, date', neighbor1Apn, neighbor1Date)

      local globalNeighborIndex2 = sortedIndices[3]
      local neighbor2Apn = trainingData.apns[globalNeighborIndex2]
      local neighbor2Date = trainingData.dates[globalNeighborIndex2]
      print('neighbor2 apn, date', neighbor2Apn, neighbor2Date)
      
      if i == 10 then halt() end
   end
   --local loss = error * error
   local loss = nil
   if options.cvLoss == 'abs' then  -- options is captured from above
      loss = math.abs(error)
   elseif options.cvLoss == 'squared' then
      loss = error * error
   else
      error('bad options.cvLoss = ' .. tostring(options.cvLoss))
   end
   if false then
      v('error,loss', error, loss)
   end
   --v('k,i,actual,est,err', k, i, actualPrice, estimatedPrice, error)

   -- report CPU seconds occassionally
   if i % 10000 == 1 then
      print(string.format('observation index %d cpu seconds %f', 
                          i, tc:cumSeconds()))
   end
   return loss
end -- cvLoss
