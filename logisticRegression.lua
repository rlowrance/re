-- logisticRegression.lua
-- NOTE: In the future, a companion function linearRegression could be written.
-- Both would call a common function to do most of the work. Each would supply
-- a model() and loss() function.

-- NOTE: Once that is done, another function iterateUnilConvergence could be
-- written. It would iterate until there was no progress on a validation set.

require 'makeNextTrainingSampleIndex'
require 'makeVp'
require 'nn'
require 'optim'

-- weighted logistic regression
-- ARG: a single table with these elements
-- inputs: 2D Tensor
-- targets: 1D Tensor of positive integers
-- weights: optional 1D Tensor of weights; default is all ones
-- isTraining: optional 1D Tensor over {0, 1}; default is all ones
-- epochs: optional number; default is 100
-- lambda: scalar number; importance of L2 regularizer
-- weightDecay: optional number, default is 0
-- momentum: optional number, default is 0
-- optimFunction: optimization function(eval, w, params) returning w', df_dw
-- optimParams: optional optimization parameters; default {}
--
-- RETURNS two values
-- state.avgLoss[i]: average loss for epoch i
-- state.weights: final weights
-- predict: function(t) returning predictions (1D) and probabilities (2D) 
--   t.inputs: 2D Tensor, required
--   t.isUsed: optional 1D Tensor over {0,1}; default all ones
--   t.verbose: optional verbose level 
function logisticRegression(t)
   assert(t ~= nil, 'must supply table as argument')
   local arg = {}
   arg.inputs = t.inputs or error('must supply inputs')
   arg.targets = t.targets or error('must supply targets')
   arg.weights = t.weights or "one"
   print('STUB: arg.weights not used')
   arg.isTraining = t.isTraining or "all"
   arg.epochs = t.epochs or 100  -- number of times to cycle over data
   arg.lambda = t.lambda or error('must supply regularizer weight lambda')
   -- TODO: optimFunction in {"sgd"}? (disallows users functions)
   arg.optimFunction = t.optimFunction or error('missing optimFunction')
   arg.optimParams = t.optimParams or {}
   arg.verbose = t.verbose or 0 
   
   local vp = makeVp(arg.verbose)
   vp(1, 'arg after defaults applied', arg)
   vp(1, 'arg.optimParams', arg.optimParams)

   -- check types and adjust inputs
   assert(arg.inputs:dim() == 2, 'inputs must be 2D Tensor')
   local p = arg.inputs:size(1)  -- number of samples
   local d = arg.inputs:size(2)  -- dimensions in input data
   assert(arg.targets:dim() == 1, 'targets must be 1D Tensor')
   assert(arg.targets:size(1) == p, 'targets size must equal nRows in inputs')
   
   if arg.weights == "one" then
      -- set all the weights to one
      arg.weights = torch.Tensor(p):fill(1)
   end
   assert(arg.weights:dim() == 1, 'weights must be 1D Tensor')
   assert(arg.weights:size(1) == p, 'weights size must equal nRows in inputs')

   if (arg.isTraining == "all") then
      -- set every observation to a training observation
      arg.isTraining = torch.Tensor(p):fill(1)
   end
   assert(arg.isTraining:dim() == 1, 'isTraining must be 1D Tensor')
   assert(arg.isTraining:size(1) == p, 
          'isTraining size must equal nRows in inputs')

   -- determine number of targets and that targets are properly formed
   local nTargets = 0
   local nTrainingSamples = 0
   for i = 1, p do
      if arg.isTraining[i] then
         nTrainingSamples = nTrainingSamples + 1
         local target = arg.targets[i]
         assert(target == math.floor(target),
                string.format('target in row %d is not an integer', i))
         assert(target > 0,
                string.format('target in row %d is not positive', i))
         if target > nTargets then
            nTargets = target
         end
      end
   end
   vp(1, 'number of samples', p)
   vp(1, 'number of training samples', nTrainingSamples)
   vp(1, 'number of targets', nTargets)

   -- define the model and optimization criterion 
   -- (regularizer is added by the eval function)
   local model = nn.Sequential()
   model:add(nn.Linear(d, nTargets))
   model:add(nn.LogSoftMax())
   local criterion = nn.ClassNLLCriterion()

   -- predict new values
   -- ARG: a table with these elements
   -- inputs: 2D Tensor, required
   -- isUsed: optional 1D Tensor on {0, 1}
   -- verbose: optional scalar, default 0
   -- RETURNS 1D Tensor of predicted target values with 0 as prediction[i] if
   -- not isUsed[i], otherwise prediction[1] \in {1, 2, ... nTargets}
   local function predict(t)
      assert(t ~= nil, 'must supply table as argument')
      local argPredict = {}
      argPredict.inputs = t.inputs or error('must supply inputs')
      argPredict.isUsed = t.isUsed or "all"
      argPredict.verbose = t.verbose or 0 
      
      local vp = makeVp(argPredict.verbose)
      vp(1, 'inputs', arg.inputs)
      vp(1, 'isUsed', arg.isUsed)
      
      -- type check and adjust inputs
      assert(argPredict.inputs:dim() == 2, 'inputs must be 2D Tensor')
      local p = argPredict.inputs:size(1)
      assert(argPredict.inputs:size(2) == d, 
             'inputs rows size differs from training data')
      
      if argPredict.isUsed == "all" then
         argPredict.isUsed = torch.Tensor(p):fill(1)
      end
      assert(argPredict.isUsed:dim() == 1, 'isUsed must be 1D Tensor')
      assert(argPredict.isUsed:size(1) == p,
             'isUsed size must equal nRows in inputs')
      
      local predictions = torch.Tensor(p):zero()
      local probabilities = torch.Tensor(p, nTargets):zero()
      for i = 1, p do
         if argPredict.isUsed[i] == 1 then
            local logProbs = model:forward(argPredict.inputs[i])
            vp(2, 'i', i)
            vp(2, 'argPredict.input[i]', argPredict.inputs[i])
            vp(2, 'logProbs', logProbs)
            -- pick largest value from the log probabiities in logProbs
            local largestIndex = 0
            local largestLogProbability = -math.huge
            for t = 1, nTargets do
               probabilities[i][t] = math.exp(logProbs[t])
               if logProbs[t] > largestLogProbability then
                  largestIndex = t
                  largestLogProbability = logProbs[t]
               end
            end
            predictions[i] = largestIndex
         end
         vp(2, 'i', i)
         vp(2, 'predictions[i]', predictions[i])
         vp(2, 'probabilities[i]', probabilities[i])
      end

      vp(1, 'predictions', predictions)
      vp(1, 'probabilities', probabilities)
      return predictions, probabilities
   end -- function predict

   -- make function that iterates over samples in random order

   local nextTrainingSampleIndex = makeNextTrainingSampleIndex(arg.isTraining)

   -- create view of parameters in the model
   local w, dl_dw = model:getParameters()

   -- evaluation function
   -- return loss(wNew, someInput, someTarget) and d_loss/d_wNew
   -- however, the last two parameters are implicit
   local function feval(wNew)  -- stochastic unrandomized samples
   local vp = makeVp(0)
      vp(1, 'feval wNew', wNew)
      if w ~= wNew then
         w:copy(wNew)
      end

      local trainingIndex = nextTrainingSampleIndex()

      local input = arg.inputs[trainingIndex]
      local target = arg.targets[trainingIndex]

      dl_dw:zero()

      local regularizer = arg.lambda * torch.cmul(w, w):sum() 
      local loss = 
           criterion:forward(model:forward(input), target) + regularizer
      local dRegularizer = w * arg.lambda * 2
      model:backward(input, 
                      criterion:backward(model.output, target))
      dl_dw:add(dRegularizer)
      vp(2, 'input', input); vp(2, 'target', target)
      vp(2, 'regularizer', regularizer)
      vp(2, 'dl_dw after regularizer', dl_dw)
      vp(2, 'dl_dw before regularizer', dl_dw)
      vp(2, 'dRegularizer', dRegularizer)
      vp(2, 'loss (regularized)', loss)

      -- print parameters
      -- NOTE: calling model:getParameters() below messes things up!
      -- THIS WAS VERY HARD TO FIND
      --vp(2, 'model parameters in feval', model:getParameters())
      vp(1, 'feval loss', loss)
      vp(1, 'feval dl_dw', dl_dw)
      return loss, dl_dw
   end -- function feval

   -- train the model
   local nTrainingSamples = arg.isTraining:sum()
   local avgLoss = {}
   for epoch = 1, arg.epochs do
      local cumulativeLoss = 0
      for obsIndex = 1, nTrainingSamples do
       	 vp(2, 'about to call arg.optimFunction', arg.optimFunction)
         vp(2, 'w', w)
       	 vp(2, 'arg.optimParams', arg.optimParams)
         local _, fNewWeightsSeq = arg.optimFunction(feval, w, arg.optimParams)
         vp(2, 'w before update', w)
         vp(2, 'params', arg.optimParams)
         vp(2, 'fNewWeightsSeq', fNewWeightsSeq)
         cumulativeLoss = cumulativeLoss + fNewWeightsSeq[1]
         vp(2, 'cumulativeLoss', cumulativeLoss)
         --if obsIndex == 1 then stop() end
      end
      avgLoss[#avgLoss + 1] = cumulativeLoss / nTrainingSamples
      vp(2, 'nTrainingSamples', nTrainingSamples)
      vp(1, string.format('epoch %d of %d: avgLoss = %f',
                          epoch, arg.epochs, avgLoss[#avgLoss]))
      --stop()
   end

   local state={avgLoss=avgLoss,
                weights=w}
   local tailSize = 10
   tailAvgLoss = torch.Tensor(tailSize)
   for i = 1, 10 do
      tailAvgLoss[i] = avgLoss[#avgLoss - tailSize + i]
   end
   vp(1, 'state.weights', state.weights)
   vp(1, 'tail state.avgLoss', tailAvgLoss)
   vp(1, 'predict', predict)
   return state, predict
end
