-- validate_test.lua
-- unit test

require 'makeVp'
require 'validate'

verbose = 0
vp = makeVp(verbose)

dataTraining = {10, 20, 30}
dataValidation = {40, 50, 39}

function train(alpha)
   local vp = makeVp(verbose, 'train')
   vp(1, 'alpha', alpha)
   local trainedModel = alpha
   vp(1, 'trainedModel', trainedModel)
   return trainedModel
end

function predict(trainedModel, alpha)
   local vp = makeVp(verbose, 'predict')
   vp(1, 'trainedModel', trainedModel)
   vp(1, 'alpha', alpha)
   local predictions = {dataValidation[alpha]}
   vp(1, 'predictions', predictions)
   return predictions
end

function loss(predictions, alpha)
   local vp = makeVp(verbose, 'loss')
   vp(1, 'predictions', prediction)
   vp(1, 'alpha', alpha)
   local lossValue = predictions[1]
   vp(1, 'lossValue', lossValue)
   return lossValue
end

alphas = {1,2,3}
res = validate(alphas, train, predict, loss)
vp(1, 'res', res)
-- best model is #3
assert(res[1] == dataValidation[1])
assert(res[2] == dataValidation[2])
assert(res[3] == dataValidation[3])

vp(0, 'ok validate_test')