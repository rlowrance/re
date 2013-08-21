-- validate.lua
-- Select model based on validation process

-- Compare models
-- ARGS
-- alphas  : seq of arbitrary objects, each identifying a model
-- train   : function(alpha) returning a model trained on training data
-- predict : function(trainedModel, alpha) return a table of predictions on
--           validation data
-- loss    : function(predictions, alpha) returning a number
--           the average loss on the predictions
-- verbose : optional number, default 0, verbose level
-- RETURNS
-- losses  : seq of losses, where losses[i] is the loss for alpha[i]
function validate(alphas,
                  train, predict, loss,
                  verbose)
   -- validate args and set defaults
   assert(type(alphas) == 'table', 'alphas not a sequence')
   assert(type(train) == 'function', 'train not a function')
   assert(type(predict) == 'function', 'predict not a function')
   assert(type(loss) == 'function', 'loss not a function')
   local verbose = verbose or 0

   local vp = makeVp(verbose, 'validate')

   -- determine loss on each model
   local losses = {}
   for i, alpha in ipairs(alphas) do
      local trainedModel = train(alpha)
      local predictions = predict(trainedModel, alpha)
      local loss = loss(predictions, alpha)
      losses[i] = loss
      vp(1, 'alpha', alpha)
      vp(1, 'loss', loss)
   end

   -- losses[i] = loss on trained model using alpha[i]
   return losses 
end
