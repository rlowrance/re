-- WLR.lua
-- weighted linear regression version 2
-- a functor

require 'nn'
require 'optim'

local WLR = torch.class('WLR')

function WLR:__init(xs, ys, query, kernel, distance, lambda)
   self.xs = xs
   self.ys = ys
   self.query = query
   self.kernel = kernel
   self.distance = distance
   self.lambda = lambda

   self.numSamples = #xs
end

-- return 1d Tensor with estimated value at query point
function WLR:estimate()
   print('estimate self', self)
   
   local model = nn.Linear(1,1)

   w, dl_dw = model:getParameters() -- tie to model parameters

   local trace = true
   local numEpochs = 1
   local currentLoss = 0
   for i=1,numEpochs do
      
      -- return loss and derivative of loss wrt weights at weights w
      -- for next sample query
      local sampleIndex = 0
      function feval(w_new)

         -- pick next sample
         sampleIndex = sampleIndex + 1
         if sampleIndex > self.numSamples then sampleIndex = 1 end
         local query = xs[sampleIndex]
         if trace then print('feval sampleIndex,query', sampleIndex, query) end

         if w_new == x then w:copy(w_new) end
         dl_dw:zero()  -- reset gradient in model
         -- accumulate loss and gradient over all the samples
         if trace then print('feval w', w) end
         local input = self.xs[sampleIndex]
         local target = self.ys[sampleIndex]
         local estimate = model:forward(input)
         local kernel = 
            self.kernel(self.query, input, self.lambda, self.distance)
         local error = torch.dist(target, estimate)
         if trace then
            print('feval input,estimate,error', input[1], estimate[1], error)
         end
         -- loss is squared error
         local sampleLoss = kernel * error * error
         if trace then print('feval cumLoss', cumLoss) end
         model:backward(input, target)
         return sampleLoss, dl_dw
      end
      if trace then 
            print('feval results', cumLoss / #self.xs, dl_dw / #self.xs)
         end
         return cumLoss / #self.xs, dl_dw / #self.xs
      end -- function feval

      local optimParams = {} -- {learningRate = 1e-30, learningRateDecay=1e-4}
      next_w, fs = optim.sgd(feval, w, optimParams)
      if trace then print('after optimize next_w,fs', next_w, fs) end
      currentLoss = currentLoss + fs[#fs]
      print('current loss = ', currentLoss)
   end -- loop over epochs

   -- model is trained, generate estimate
   print('LWR:estimate query', self.query)
   local result = model:forward(self.query)
   print('LWR:estimate result', result)
   return result
end