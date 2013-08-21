-- sgdBottouDriver.lua

require 'makeVp'
require 'optim'
require 'sgdBottou'
require 'validateAttributes'

-- use optim.sgdBottou to optimize a function
-- ARGS
-- opfunc    : function(x, index) --> loss, gradient
--             as needed for optim.sgdBottou
-- config    : table of configuration parameters a needed for optim.sgdBottou
-- nSamples  : number > 0
-- initialX  : 1D Tensor
-- tolX      : optional number, iterations stop if norm(x_t - x_{t+1}) < tolX
--             test is performed at the end of an epoch, so t = epoch number
-- tolF      : optional number, iterations stop if |f(x_t) - f(x_{t+1})| < tolF
--             test is performed at end of an epoch using the average loss for the epoch
-- maxEpochs : no more than this number of epochs are run
-- verbose   : optional number, default 0
--             if verbose == 1 then print the avg loss for each epoch
--             if verbose == 2 then also print the weight vector at the end of each epoch
-- RETURNS
-- xStar     : optimal x value found
-- avgLoss   : number, average loss from last Epoch
-- state     : table, final state from optim.sgdBottou
function sgdBottouDriver(opfunc, config, nSamples, initialX, 
                         tolX, tolF, maxEpochs, 
                         verbose)
   local vp = makeVp(1, 'sgdBottouDriver')

   -- validate args
   validateAttributes(opfunc, 'function')
   validateAttributes(config, 'table')
   validateAttributes(nSamples, 'number', '>', 0)
   validateAttributes(initialX, 'Tensor', '1D')
   validateAttributes(tolX, {'number', 'nil'})
   validateAttributes(tolF, {'number', 'nil'})
   validateAttributes(maxEpochs, {'number', 'nil'})
   validateAttributes(verbose, {'number', 'nil'})
   assert(tolX ~= nil or tolF ~= nil or maxEpochs ~= nil)

   -- provide defaults
   if verbose == nil then
      verbose = 0 
   end
   
   -- run an epoch using the specified weight (=x)
   -- return updated weight and average loss for the epoch
   local state = {}
   local function epoch(xArg)
      local vp = makeVp(0, 'epoch')
      vp(1, 'xArg', xArg)
      local sumLosses = 0
      local x = xArg:clone()  -- don't change caller's arg value
      for iteration = 1, nSamples do
         vp(2, 'x before update', x)
         validateAttributes(x, 'Tensor')
         local xNew, losses = optim.sgdBottou(opfunc, x, config, state)
         vp(2, 'x after update', xNew)
         x = xNew
         sumLosses = sumLosses + losses[1]
      end
      local avgLoss = sumLosses / nSamples
      return x, avgLoss
   end

   -- iterate until convergence
   local x = initialX
   local lastAvgLoss = math.huge
   local nEpochs = 0
   local lastX = nil
   local lastAvgLoss = nil
   repeat 
      local newX, avgLoss = epoch(x)
      nEpochs = nEpochs + 1
      x = newX

      if lastAvgLoss ~= nil and avgLoss > lastAvgLoss then
         -- loss is increasing; decrease step size eta
         state.eta = state.eta / 2
         if verbose > 0 then
            print('loss increasing, reduced eta to ' .. tostring(state.eta))
         end
      end
      
      if verbose > 0 then
         local s = string.format('epoch %d avg loss %f', nEpochs, avgLoss)
         if verbose == 1 then
            vp(0, s)
         elseif verbose == 2 then
            vp(0, s .. ' weights', x)
         end
      end

      -- perform each convergence test
      local testX = tolX ~= nil and nEpochs > 1 and torch.norm(x - lastX) < tolX
      if testX then
         state.converged = 'tolX'
      end

      local testF = tolF ~= nil and nEpochs > 1 and math.abs(avgLoss - lastAvgLoss) < tolF
      if testF then
         state.converged = 'testF'
      end

      local epochTest = maxEpoch ~= nil and nEpochs >= maxEpochs
      if epochTest then
         state.converged = 'maxEpochs'
      end
            
      local converged = testX or testF or epochTest
      
      lastX = x
      lastAvgLoss = avgLoss
   until converged
      
   return x, lastAvgLoss, state
end