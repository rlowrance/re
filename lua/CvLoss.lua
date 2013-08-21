-- CvLoss.lua

-- API overview
if false then
   cl = CvLoss(trainingXs, trainingYs, options)

   local function makeFittedModel(fold, kappa, alpha,
                                  trainingXs, trainingYs, 
                                  makeFittedModelExtraArg,
                                  options)
      -- return a model fitted to the observations not in the fold
      -- kappa[i] is the fold for observation i
      return model
   end
   
   alphaStar, lossTable = cl:run(alpha, i, kappa, 
                                 makeFittedModel, makeFittedModelExtraArg)
end

--------------------------------------------------------------------------------
-- CONSTRUCTION
--------------------------------------------------------------------------------

torch.class('CvLoss')

function CvLoss:__init(trainingXs, trainingYs, options)
   -- ARGS
   -- trainingXs : xs before division into fitting and validation
   -- trainingYs : ys before division into fitting and validation
   -- options    : table
   affirm.isTensor2D(trainingXs, 'trainingXs')
   affirm.isTensor1D(trainingYs, 'trainingYs')
   affirm.isTable(options, 'options')
   assert(options.cvLoss,
          'options must have field cvLoss')
   assert(options.cvLoss == 'abs' or self._options.cvLoss == 'squared',
          'bad options.cvLoss = ' .. tostring(options.cvLoss))

   self._trainingXs = trainingXs
   self._trainingYs = trainingYs
   self._options = options

   self._miInstance = nil   -- cannot create now, since don't know kappa
   self._fittedModels = {}  -- build this up gradually, as we see new folds
end -- _init

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

function CvLoss:run(alpha, i, kappa, 
                    makeFittedModel, makeFittedModelExtraArg)
   -- return loss on observation i (in fold kappa[i])
   -- from model fitted with observations not in fold kappa[i]
   -- define loss as the absolute value of the estimation error
   -- or as the squared error, depending on options.cvLoss
   -- ARGS
   -- alpha    : some object usable as arg to fitModel and useModel
   -- i        : integer > 0, index of global observation number
   -- kappa    : sequence of integer > 0
   --            kappa[i] is the fold number of observation i
   -- makeFittedModel         : function that takes args
   --                           (alpha, i, kappa, makeFittedModelExtraArg)
   --                           and returns a model fitted on all 
   --                           the observations not in fold kappa[i]
   -- makeFittedModelExtraArg : object passed to makeFittedModel
   -- RETURNS
   --  true, loss    : if model:estimates succeeds
   --  false, reason : if model:estimates() fails

   -- The model returned by makeFittedModel must satisfy
   -- model.ys : 1D Tensor of prices or other target values
   -- ok, estimate, usedCache, sortedIndices = model:estimate(query, alpha)
   
   local v = makeVerbose(false, 'cvLoss')
   v('alpha', alpha)
   v('i', i)
   v('kappa', kappa)
   v('makeFittedModel', makeFittedModel)
   v('makeFittedModelExtraArg', makeFittedModelExtraArg)

   local tc = TimerCpu()
   collectgarbage()   -- avoid bug in torch7

   assert(alpha ~= nil, 'alpha cannot be nil')
   affirm.isIntegerPositive(i, 'i')
   affirm.isSequence(kappa, 'kappa')
   affirm.isFunction(makeFittedModel, 'makeFittedModel')
   -- makeFittedModelExtraArg is possible nil

   local fold = kappa[i]
   local model = self._fittedModels[fold]
   if model == nil then
      -- create and fit model to all the data in the fold
       model = makeFittedModel(fold,
                               kappa,
                               alpha,
                               self._trainingXs,
                               self._trainingYs,
                               makeFittedModelExtraArg,
                               self._options)
       self._fittedModels[fold] = model
   end
   v('model', model)
   
   if self._miInstance == nil then
      self._miInstance = ModelIndex(kappa)
   end
   v('self._miInstance', self._miInstance)

   -- BUG (FIXED): should use the global index, not the local index
   --              and should estimate, not smooth because
   --              the query transaction is not in the fitting data

   local actualPrice = self._trainingYs[i]
   local ok, estimatedPrice =  model:estimate(self._trainingXs[i], alpha)
   if not ok then
      -- estimatedPrice is the reason no estimate was provided
      print(string.format('CvLoss failed to estimate alpha %s i %d reason %s',
                          tostring(alpha), i, estimatedPrice))
      return false, estimatedPrice

   end
   local error = actualPrice - estimatedPrice
   v('kappa', kappa)
   v('i,modelObsIndex', i, modelObsIndex)
   v('actualPrice', actualPrice)
   v('estimatedPrice', estimatedPrice)
   v('error', error)

   --determine loss
   local loss = nil
   if self._options.cvLoss == 'abs' then  -- options is captured from above
      loss = math.abs(error)
   elseif self._options.cvLoss == 'squared' then
      loss = error * error
   else
      error('bad options.cvLoss = ' .. tostring(self._options.cvLoss))
   end

   -- report CPU seconds occassionally
   if i % 10000 == 1 then
      print(string.format('observation index %d cpu seconds %f', 
                          i, tc:cumSeconds()))
   end
   v('loss', loss)
   return true, loss
end -- cvLoss

