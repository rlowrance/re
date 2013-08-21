-- WeightedLinearRegression.lua
-- define class WeightedLinearRegression

-- torch libraries
require 'nn'
require 'optim'

-- local libraries
require 'Trainer'
require 'Validations'
require 'WeightedMSECriterion'


local WeightedLinearRegression = torch.class('WeightedLinearRegression')

function WeightedLinearRegression:__init(inputs, targets, numDimensions)
   -- validate parameters
   Validations.isTable(self, 'self')
   Validations.isNotNil(inputs, 'inputs')
   Validations.isNotNil(targets, 'targets')
   Validations.isIntegerGt0(numDimensions, 'numDimensions')

   -- save data for type validations
   self.inputs = inputs
   self.targets = targets
   self.numDimensions = numDimensions

end

function WeightedLinearRegression:estimate(query, weights, opt)
   -- validate parameters
   Validations.isTable(self, 'self')
   Validations.isTensor(query, 'query')
   Validations.isNotNil(weights, 'weights')
   Validations.isTable(opt, 'opt')

   -- define model
   self.model = nn.Sequential()
   local numOutputs = 1
   self.model:add(nn.Linear(self.numDimensions, numOutputs))

   -- define loss function
   self.criterion = nn.MSECriterion()

   -- iterate to a solution
   -- first with SGD then with L-BFGS
   if false then
      print('\nestimate self', self)
      print('estimate opt', opt)
      print('estimate opt.sgd', opt.sgd)
   end

   self:_iterate(optim.sgd,
                 opt.sgd.epochs,
                 opt.sgd.batchSize,
                 opt.sgd.params,
                 weights)
   self:_iterate(optim.lbfgs,
                 opt.lbfgs.epochs,
                 opt.lbfgs.batchSize,
                 opt.lbfgs.params,
                 weights)

   return self.model:forward(query)
end

function WeightedLinearRegression:_iterate(optimize,
                                           numEpochs,
                                           batchSize,
                                           optimParms,
                                           weights)
   -- validate parameters
   Validations.isFunction(optimize, 'optimize')
   Validations.isNumber(numEpochs, 'numEpochs')
   Validations.isNumberGt0(batchSize, 'batchSize')
   Validations.isNilOrTable(optimParams, 'optimParams')
   Validations.isTable(weights, 'weights')

   if false then
      print('_iterate self', self)
      print('_iterate numEpochs', numEpochs)
      print('_iterate batchSize', batchSize)
      print('_iterate num weights', #weights)
      print('_iterate optimParams', optimParms)
   end

   x, dl_dx = self.model:getParameters() -- create view of parameters
   
   for epochNumber =1,numEpochs do
      currentLoss = 0
      local highestIndex = 0
      local numBatches = 0
      for batchNumber = 1,#self.inputs do
         if highestIndex >= #self.inputs then break end
         numBatches = numBatches + 1
         local batchIndices = {}
         for b=1,batchSize do
            local nextIndex = (batchNumber - 1) * batchSize + b
            --print('_iterate nextIndex', nextIndex)
            if nextIndex <= #self.inputs then
               batchIndices[#batchIndices + 1] = nextIndex
               highestIndex = nextIndex
            end
         end
         if false then
            print('_iterate batchNumber', batchNumber)
            print('_iterate batchSize', batchSize)
            print('_iterate batchIndices', batchIndices)
         end

         function feval(x_new)
            if x ~= x_new then x:copy(x_new) end
            dl_dx:zero()  -- reset gradient in model
            local cumLoss = 0
            local numInBatch = 0
            -- iterate over the indices in the batch
            for _,nextIndex in pairs(batchIndices) do
               numInBatch = numInBatch + 1
               local input = self.inputs[nextIndex]
               local target = self.targets[nextIndex]
               Validations.isTensor(input, 'inputs[nextIndex]')
               Validations.isTensor(target, 'targets[nextIndex]')
               local modelOutput = self.model:forward(input)
               --print('feval input', input)
               --print('feval target', target)
               local lossUnweighted = 
                  self.criterion:forward(self.model:forward(input), target)
               local lossWeighted = weights[nextIndex] * lossUnweighted
               cumLoss = cumLoss + lossWeighted
               self.model:backward(input, 
                                   self.criterion:backward(input, target))
            end
            return cumLoss / numInBatch, dl_dx / numInBatch
         end -- function feval
         
         _, fs = optimize(feval, x, optimParams)
         if opt.verboseBatch then
            print('loss values during optimization procedure', fs)
         end
            -- the last value in fs is the value at the optimimum x*
         currentLoss = currentLoss + fs[#fs]
      end -- loop over batches
      
      -- finished with all the batches
      currentLoss = currentLoss / numBatches
      if opt.verboseEpoch then
         print(string.format('epoch %d of %d; current loss = %.15f',
                             epochNumber, numEpochs,
                             currentLoss))
      end
   end -- loop over epochs
end -- method _iterate
