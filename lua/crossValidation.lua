-- crossValidation.lua

require 'affirm'
require 'makeVerbose'
require 'shuffleSequence'
require 'TimerCpu'

local function tabulate(alphas, alphaCumLoss, alphaAttempts, alphaAvailable)
   -- find best alpha and compute loss and coverage tables
   local v = makeVerbose(false, 'crossValidation::tabulate')

   local bestAlpha = nil
   local lowestAvgLoss = math.huge
   local alphaAvgLoss = {}
   local alphaCoverage = {}

   for _, alpha in ipairs(alphas) do
      local cumLoss = alphaCumLoss[alpha]
      local attempts = alphaAttempts[alpha]
      local available = alphaAvailable[alpha]
      v('alpha,cumLoss,attempts,available', alpha, cumLoss, attempts, available)
      local avgLoss = cumLoss / available
      local coverage = available / attempts
      v('alpha,avgLoss,coverage', alpha, avgLoss, coverage)
      
      alphaAvgLoss[alpha] = avgLoss
      alphaCoverage[alpha] = coverage

      if avgLoss < lowestAvgLoss then
         bestAlpha = alpha
         lowestAvgLoss = avgLoss
      end
   end -- loop over alphas

   return bestAlpha, alphaAvgLoss, alphaCoverage
end -- tabulate

local function printResults(alphas, bestAlpha, alphaAvgLoss, alphaCoverage)
   print('\nInterim results from cross validation')
   print('best alpha so far', bestAlpha)
   print()
   for _, alpha in ipairs(alphas) do
      if alphaAvgLoss[alpha] then
         print('alpha', alpha)
         print(' avg loss', alphaAvgLoss[alpha])
         print(' coverage', alphaCoverage[alpha])
      end
   end
end -- printResults


function crossValidation(alphas, nFolds, nObservations,
                         trainingXs, trainingYs,
                         modelFit, modelUse, modelState,
                         options)
   -- perform k-fold cross validation searching for best parameter in alphas
   -- ARGS
   -- alphas        : sequence of tuning parameters to consider
   --                 each tuning parameter can be anything, including a table
   -- nFolds        : integer > 0, number of folds in the cross validation
   --                 cvLoss is called nFolds times
   -- nObservations : integer > 0, number of observations in dataset
   -- trainingXs    : 2D Tensor
   -- trainingYs    : 1D Tensor
   -- modelFit      : function returning a model fitted to all data not
   --                 in a specified fold (the fitting data)
   -- modelUse      : function returning ok, estimate using a fitted model
   --                 for a specific estimate in a validation set
   -- modelState    : table passed to modelFit and modelUse functions
   -- options       : table of command line options
   --                 option.cvLoss \in {'abs', 'squared'}
   -- RETURNS 
   -- alphaStar     : number, average loss across all validation folds
   --                 an estimate of the generalized error
   -- lossTable     : table[alpha] = avg loss for the alpha
   -- coverageTable : table[alpha] = fraction of estimates that had ok = true
   --
   -- where

   -- modelFit(alpha, removedFold, kappa, 
   --          trainingXs, trainingYs, modelState, options) 
   -- ARGS
   -- alpha       : model identifier, one of the alphas
   -- removedFold : number, transactions in the fold are not used for fitting
   --               the model
   -- kappa        : kappa[i] = fold number for global observation i
   -- trainingXs   : 2D Tensor
   -- trainingYs   : 1D Tensor
   -- modelState   : table, usually contains the global xs and ys
   -- options      : table of command line parameters
   -- RETURNS
   -- model        : trained on all observations for which
   --                kappa[i] ~= removedFold

   -- modelUse(alpha, model, x, modelState, options) 
   -- ARGS
   -- alpha         : model identifier, one of the alphas
   -- model         : model returned by modelFit
   -- i             : index of one of the trainingXs, use it to make an estimate
   -- modelState : table passed originally and possibly modified by modelFit
   --              this is where all the training observations are kept
   -- options    : table, command line options
   -- RETURNS
   -- true, estimate  , if observation i could be estimated with model alpha
   -- false, reasons  , otherwise.
   -- REF: Hastie, 2001, p215
   -- Features of the implementation:
   -- 1. at most one instance of the model created by modelFit exists while
   -- this function executes.

   local v, verbose = makeVerbose(false, 'crossValidation')

   verify(v,
          verbose,
          {{alphas, 'alphas', 'isSequence'},
           {nFolds, 'nFolds', 'isIntegerPositive'},
           {nObservations, 'nObservations', 'isIntegerPositive'},
           {trainingXs, 'trainingXs', 'isTensor2D'},  -- or table
           {trainingYs, 'trainingYs', 'isTensor1D'},  -- or table
           {modelFit, 'modelFit', 'isFunction'},
           {modelUse, 'modelUse', 'isFunction'},
           {modelState, 'modelState', 'isTable'},
           {options, 'options', 'isTable'}})

   assert(options.cvLoss ~= nil,
          'options.cvLoss was nil, must be "abs" or "squared"')
   assert(options.cvLoss == 'abs' or
          options.cvLoss == 'squared',
          'options.cvLoss must be "abs" or "squared", was ' .. options.cvLoss)

   -- assign each possible observation index to a fold
   -- as evenly as possible
   local kappa = {}
   local foldNumber = 1
   for i = 1, nObservations do
      kappa[#kappa + 1] = foldNumber
      foldNumber = foldNumber + 1
      if foldNumber > nFolds then
         foldNumber = 1
      end
   end

   -- randomize the fold assignments
   -- kappa[i] = the fold number for observation i
   local kappa = shuffleSequence(kappa)  -- permute randomly
   v('kappa', kappa)
   assert(nObservations, #kappa)
   
   -- determine average loss for each alpha
   -- select alpha with lowest average loss
   local lossTable = {}     -- key = alpha value = average loss for alpha
   local coverageTable = {} -- key = alpha 
                            -- value = fraction where loss is available

   -- keep track of losses and coverage for each alpha
   alphaCumLoss = {}
   alphaAttempts = {}
   alphaAvailable = {}
   for _, alpha in ipairs(alphas) do
      alphaCumLoss[alpha] = 0
      alphaAttempts[alpha] = 0
      alphaAvailable[alpha] = 0
   end

   for _, alpha in ipairs(alphas) do
      print('crossValidation: alpha', alpha)
      -- work fold by fold to avoid keeping more than one fitted model around
      for removedFold = 1, nFolds do
         print('crossValidation: alpha', alpha)
         print('crossValidation: removedFold', removedFold)
         -- fit model to all observations but this in the removed fold
         local model = modelFit(alpha, removedFold, kappa, 
                                trainingXs, trainingYs,
                                modelState, options)
         for i = 1, nObservations do
            v('removedFold,i,kappa[i]', removedFold, i, kappa[i])
            if kappa[i] == removedFold then
               -- observation i is in the fold
               local tc = TimerCpu()
               alphaAttempts[alpha] = alphaAttempts[alpha] + 1
               local ok, estimate = 
                  modelUse(alpha, model, i,  modelState, options)
               if ok then
                  local actual = trainingYs[i]
                  v('actual,estimate', actual, estimate)
                  local loss = math.abs(actual - estimate)
                  if options.cvLoss == 'squared' then
                     loss = loss * loss
                  end
                  v('actual, loss', actual, loss)
                  alphaCumLoss[alpha] = alphaCumLoss[alpha] + loss
                  alphaAvailable[alpha] = alphaAvailable[alpha] + 1
               else
                  -- estimate is the reason no loss was provided
                  -- for now, don't keep track of the reasons
                  print(string.format('crossValidation: %d not estimated %s',
                                      i, tostring(estimate)))
               end
               if i % 10000 == 1 then
                  print('crossValidation: programName', options.programName)
                  print('crossValidation: alpha', alpha)
                  print('crossValidation: removedFold', removedFold)
                  print('training obs index', i)
                  print('crossValidation: cpu sec', tc:cumSeconds())
               end
            end -- in correct fold
         end -- loop for all observations
      end -- loop for all folds
      print('\nResults so far')
      bestAlpha, alphaAvgLoss, alphaCoverage = tabulate(alphas,
                                                        alphaCumLoss,
                                                        alphaAttempts,
                                                        alphaAvailable)
      printResults(alphas, bestAlpha, alphaAvgLoss, alphaCoverage)
   end -- loop for all alphas

   v('alphaCumLoss', alphaCumLoss)
   v('alphaAttempts', alphaAttempts)
   v('alphaAvailable', alphaAvailable)

   local bestAlpha, alphaAvgLoss, alphaCoverage = tabulate(alphas,
                                                           alphaCumLoss,
                                                           alphaAttempts,
                                                           alphaAvailable)
   return bestAlpha, alphaAvgLoss, alphaCoverage
end -- crossValidation

function crossValidationOLD(alphas, cvLoss, nFolds, nObservations, verbose)
   -- perform k-fold cross validation searching for best parameter in alphas
   -- ARGS
   -- alphas        : sequence of tuning parameters to consider
   --                 each tuning parameter can be anything, including a table
   -- cvLoss        : function to compute the loss for a given fold (see below)
   -- nFolds        : integer > 0, number of folds in the cross validation
   --                 cvLoss is called nFolds times
   -- nObservations : integer > 0, number of observations in dataset
   -- verbose       : optional boolean, default false
   --                 if true, diagnostic information is printed
   -- RETURNS 
   -- alphaStarIndex : number
   --                  index in alphas of alpha with lowest 
   --                  average estimated loss
   -- lossTable      : table, one element for each alpha
   --                    key = alpha
   --                    value = avg loss across folds for the alpha
   -- coverageTable  : table, one element for each alpha
   --                    key = alpha
   --                    value = fraction of observations for which an
   --                            loss was provided by the cvLoss function
   -- where
   --    cvLoss(alpha, i, kappa) is a function that fits the model to
   --    the observations not in fold kappa[i] and returns the loss for
   --    the observations in fold kappa[i] using the fitted model
   --    ARGS:
   --    alpha    : a tuning parameter, one of the alphas
   --    i        : observation number
   --    kappa    : sequence such that 
   --               kappa[i] is the fold number
   --    RETURNS
   --    lossValue : number, the loss at the un-selected observations using
   --                the optimal parameters. The loss might be
   --                  average of squared errors
   --                  average of absolute errors
   -- REF: Hastie, 2001, p215
   -- This version does not directly compute the loss on folds but simply
   -- averages across the folds

   local v = makeVerbose(true, 'crossValidation')

   -- type and value check
   affirm.isSequence(alphas, 'alphas')
   affirm.isFunction(cvLoss, 'cvLoss')
   affirm.isIntegerPositive(nFolds, 'nFolds')
   affirm.isIntegerPositive(nObservations, 'nObservations')

   -- assign each possible observation index to a fold
   -- as evenly as possible
   local kappa = {}
   local foldNumber = 1
   for i = 1, nObservations do
      kappa[#kappa + 1] = foldNumber
      foldNumber = foldNumber + 1
      if foldNumber > nFolds then
         foldNumber = 1
      end
   end

   -- randomize the fold assignments
   -- kappa[i] = the fold number for observation i
   local kappa = shuffleSequence(kappa)  -- permute randomly
   v('kappa', kappa)
   assert(nObservations, #kappa)
   
   -- determine average loss for each alpha
   -- select alpha with lowest average loss
   local cv = {}  -- key = alpha value = average loss for alpha
   local coverage = {} -- key = alpha value = fraction where loss is available
   local lowestCvLoss = math.huge
   local alphaStar = nil
   for _, alpha in ipairs(alphas) do
      local cumLoss = 0
      local countLossAvailable = 0
      for i = 1, nObservations do
         local ok, loss = cvLoss(alpha, i, kappa)
         --v('ok,loss', ok, loss)
         if ok then
            countLossAvailable = countLossAvailable + 1
            cumLoss = cumLoss + loss
         else
            -- loss is the reason no loss was provided
            -- for now, don't keep track of the reasons
         end
      end -- loop for all observations
      local avgLoss = cumLoss / countLossAvailable
      cv[alpha] = avgLoss
      --v('countLossAvailable', countLossAvailable)
      --v('nObservations', nObservations)
      coverage[alpha] = countLossAvailable / nObservations
      v('alpha,avgLoss', alpha, avgLoss)
      if avgLoss < lowestCvLoss then
         lowestCvLoss = avgLoss
         alphaStar = alpha
      end
   end -- loop for all alphas

   v('coverage', coverage)
   v('cv', cv)
   v('alphaStar', alphaStar)
   return alphaStar, cv, coverage
end -- crossValidation

