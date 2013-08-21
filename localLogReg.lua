-- localLogReg.lua

require 'makeVp'
require 'modelLogreg'
require 'Timer'

-- make a prediction using a local logistic regression model
-- ARGS:
-- xs     : 2D Tensor size m x n, each row an observation
-- ys     : 2D Tensor size m x 1, of classes in {1, 2, ..., nClasses}
-- ws     : 2D Tensor size m x 1, the importance of each xs[i] to newX
-- newX   : 2D Tensor size 1 x n, point of prediction
-- lambda : number, lambda for L2 regularizer
-- RETURNS
-- prediction : number in {1, ..., nClasses}, predicted class for newX
function localLogReg(xs, ys, ws, newX, lambda)
   local vp, verbose = makeVp(2, 'localLogReg')
   local d = verbose > 0
   if d then
      vp(1, '\n******************* localLogReg')
      vp(1, 
         --'head xs', head(xs),
         --'head ys', head(ys),
         --'head ws', head(ws),
         'xs size', xs:size(),
         'ys size', ys:size(),
         'ws size', ws:size(),
         'newX', newX,
         'lambda', lambda)
   end

   -- validate input
   assert(xs:dim() == 2)
   assert(ys:dim() == 2)
   assert(ws:dim() == 2)
   assert(newX:dim() == 2, 'newX is not 2D Tensor; dim = ' .. newX:dim())
   assert(type(lambda) == 'number' and lambda >= 0)

   local nObs = xs:size(1)
   assert(ys:size(1) == nObs and ys:size(2) == 1)
   assert(ws:size(1) == nObs and ws:size(2) == 1)

   local nDimensions = xs:size(2)
   assert(newX:size(2) == nDimensions)

   -- determine number of classes and check coding of classes
   assert(1 <= ys:min())
   local nClasses = ys:max()
   vp(2, 'nClasses', nClasses)
   assert(nClasses >= 2)
   assert(nClasses == math.floor(nClasses))  -- nClasses is integer
   -- The subset we see may have less than the max number of heating codes
   --assert(nClasses == 4) -- for HEATING.CODE

   if d then 
      vp(2, 'nObs', nObs, 'nDimensions', nDimensions, 'nClasses', nClasses)
   end

   -- fit the model
   config = {nClasses=nClasses,
             nDimensions=nDimensions,
             verbose=0,
             checkArgs=true}
   vp(2, 'fitting modelLogReg')
   local timer = Timer()
   local thetaStar = modelLogreg.fit(config, xs, ys, ws, lambda)
   vp(2, 'thetaStar', thetaStar)
   vp(1, 'cpu seconds to fit model', timer:cpu())
   assert(not hasNaN(thetaStar))
   stop()

   -- predict at the query point
   local predictions, probs = modelLogreg.predict(config,
                                                  thetaStar,
                                                  newX)

   vp(1, 'predictions', predictions, 'probs', probs)
   assert(predictions:dim() == 2 and 
          predictions:size(1) == 1 and
          predictions:size(2) == 1)
   local prediction = predictions[1][1]
   vp(1, 'prediction', prediction)
   assert(1 <= prediction)
   assert(prediction <= nClasses)
   return prediction
end

   

   
   