-- sgdBottou.lua

require 'makeVp'
require 'optim'
require 'pressEnter'
require 'validateAttributes'


-- An implementation of Leon Bottou's idea for dynamically adjusting the learning rate eta.
-- 
-- Ref: leon.bottou.org/slides/largescale/lstut.pdf page 37
-- Bottou's idea:
-- The update is w_{t+1} := w_t - eta gradient(w_t, x_t, y_t)
-- "At any moment during training, we can:
--  - Select a small subsample of the examples.
--  - Try various gains eta on the subsample.
--  - Pick the gain eta that most reduces the cost.
--  - Use it for the next 100000 iterations on the full dataset."
--
-- ARGS:
-- opfun  : function(x, [index]) --> f(x), df/dx
--          return the loss and gradient using point x and one sample
--          x     : 1D Tensor, the weights (aka, the parameters, theta)
--          index : optional integer > 0, example number to use
--                  if not supplied, use a random sample (for example, iterate through
--                  all the samples in random order)
--                  when doing normal iterations, the call is opfunc(x)
--                  when testing on a subsample, the all is opfunc(x, subsampleindex)
-- x      : 1D Tensor, the initial point
-- config : table of configuration variables
--          config.nSamples    : integer > 0, number of samples
--          config.nSubsamples : integer > 0, number of subsamples (<= nSamples)
--          config.eta         : initial eta
--          config.newEtas     : function(eta) --> {eta1, eta2, ..., etaN}
--                               eta's to test on the subsample
--                               current eta value is added to this set
--          config.evalCounter : number of iterations before finding a new eta
--          config.printEta    : if true, print eta when it changes
-- state  : table describing state of the optimizer
--          considered private, so may vary in different implementations
-- RETURNS
-- x      : new x vector
-- f(x)   : table with one entry, the function value, before the update
function optim.sgdBottou(opfunc, x, config, state)
   local reportTiming = global.reportTiming.sgdBottou and false
   local vp, verboseLevel = makeVp(0, 'optim.sgdBottou')
   local timer = Timer(vp)

   vp(1, 'config', config)
   validateAttributes(opfunc, 'function')
   validateAttributes(x, 'Tensor', '1D')
   validateAttributes(config, 'table')
   validateAttributes(state, 'table')

   -- initialize state using values in config
   if state.evalCounter == nil then
      state.evalCounter = 0
   end

   if state.eta == nil then
      state.eta = config.eta
   end
   vp(1, 'state after initialization', state)

   -- initially and periodically explore new eta values
   if state.evalCounter == 0 or state.evalCounter % config.evalCounter == 0 then
      if reportTiming then
         vp(0, 'state.evalCounter', state.evalCounter, 'config.evalCounter', config.evalCounter)
      end

      if verboseLevel >= 3 then
         -- pressEnter('starting search for better eta')
      end

      local currentX = x

      -- construct random subsample
      local randperm = torch.randperm(config.nSamples)

      local etas = config.newEtas(state.eta)  -- candidate etas

      -- determine average loss on the sub sample for some eta value
      local function avgLossOnSubsample(eta)
         local x = currentX  -- start with current eta value
         for i = 1, config.nSubsamples do
            loss, gradient = opfunc(x, randperm[i])
            x = x - gradient * eta
               totalLoss = totalLoss + loss
         end
         local avgLoss = totalLoss / config.nSubsamples
         return avgLoss
      end

      -- determine average loss and updated weights for a candidate eta value
      local function testCandidate(candidateEta)
            local totalLoss = 0
            local x = currentX   -- start each test at the same theta value
            for i = 1, config.nSubsamples do
               local loss, gradient = opfunc(x, randperm[i])
               x = x - gradient * candidateEta
               totalLoss = totalLoss + loss
            end
            return totalLoss / config.nSubsamples, x
      end

      -- determine best Eta from the candidates
      -- return bestEta and loss for best eta and weights for best eta
      local function testCandidates(candidateEtas)
         local vp = makeVp(0, 'testCandidates')
         vp(1, 'candidateEtas', candidateEtas)
         vp(1, 'config.nSubsamples', config.nSubsamples)
         local bestEta = nil
         local bestLoss = math.huge
         local bestX = nil
         
         for _, eta in ipairs(candidateEtas) do
            local candidateLoss, candidateX = testCandidate(eta)
            --vp(0, 'eta', eta, 'avgLoss', avgLoss)
            if candidateLoss < bestLoss then
               bestEta = eta
               bestLoss = candidateLoss
               bestX = x
            end
         end

         if bestEta == nil then
            error('none of the candidate etas had a loss < infinity')
         end

         vp(1, 'bestEta', bestEta, 'bestLoss', bestLoss)
         return bestEta, bestLoss, bestX
      end

      local function union(some, another)
         for _, one in ipairs(some) do
            if one == another then
               return some
            end
         end
         table.insert(some, another)
         return some
      end

      -- determine and start to use the best eta, also considering the current eta
      local bestEta, bestLoss, bestX = 
         testCandidates(union(config.newEtas(state.eta), state.eta))
      state.eta = bestEta   

      -- keep track of all the eta values
      if state.etas == nil then
         state.etas = {bestEta}
      else
         table.insert(state.etas, bestEta)
      end

      -- restart the iterations using the best result from the candidate explorations
      x = bestX

      if config.printEta then
         if verboseLevel >= 3 then
            pressEnter('eta updated to ' .. tostring(state.eta))
         end
      end

      if reportTiming then
         vp(0, string.format('new best eta %f; cpu sec %f', bestEta, timer:cpu()))
         timer:reset()
      end
   end

   -- take one step of size eta
   validateAttributes(x, 'Tensor')
   local loss, gradient = opfunc(x)
   x = x - gradient * state.eta
   validateAttributes(x, 'Tensor')
   state.evalCounter = state.evalCounter + 1
   vp(3, 'evalCounter', evalCounter, 'updated x', x, 'loss before update', loss)

   if reportTiming then
      vp(0, 'take step; cpu sec', timer:cpu())
      timer:reset()
   end

   return x, {loss}
end

if false then
   -- print the optim table
   print('optim table as defined in sgdBottout.lua')
   for k, v in pairs(optim) do
      print('optim.' .. tostring(k) .. '=' .. tostring(v))
   end
end
