-- modelUseKernelSmoother.lua
-- helper function from crossValidate when the model is a KernelSmoother

function modelUseKernelSmoother(alpha, i, kappa, 
                                model, modelState, 
                                options)
   -- return loss using model on the i-th observation with alpha == k
   -- ARGS
   -- alpha      : identifier of the model
   --              not used
   -- i          : integer > 0, 
   --              transaction index in all observations to estimate
   --              not used
   -- kappa      : sequence such that kappa[i] is the fold number for
   --              global transaction i
   --              not used
   -- model      : a KernelSmoother (Knn, Kwavg, Llr instance)
   --              model has been fitted for parameter alpha
   -- modelState : table containing field modelState.xs, a 2D Tensor
   -- options    : table of program options
   --              options.cvLoss determines how the error is translated
   --              into a loss
   -- RETURNS
   --   true, loss    : an estimate was available
   --   false, reason : an estimate was not available
   local v, isVerbose = makeVerbose(false, 'modelUseKernelSmoother')
   verify(v,
          isVerbose,
          {{alpha, 'alpha', 'isNotNil'},
           {i, 'i', 'isIntegerPositive'},
           {kappa, 'kappa', 'isTable'},
           {model, 'model', 'isNotNil'},
           {modelState, 'modelState', 'isTable'},
           {options, 'options', 'isTable'}})

   local ok, estimate = model:estimate(modelState.allXs[i], alpha)
   if not ok then
      print(string.format('modelUse; obs %d error %s',
                          i, estimate))
      return false, estimate
   end
   local actual = modelState.allYs[i]
   local error = estimate - actual

   local loss
   if options.cvLoss == 'abs' then
      loss = math.abs(error)
   elseif options.cvLoss == 'squared' then
      loss = error * error
   else
      error('bad options.cvLoss = ' .. tostring(options.cvLoss))
   end
   v('estimate,actual,error', estimate, actual, error)
   collectgarbage()
   return true, loss
end -- modelUse
