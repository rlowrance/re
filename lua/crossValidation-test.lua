-- crossValidation-test.lua
-- unit test

require 'all'

tester = Tester()
test = {}

function test.one()
   -- actual model y = 2 x + 1 + epsilon
   -- epsilon ~ N(0,.1)
   -- models tested are of the form y = ax + b

   local v = makeVerbose(false, 'test.alphaModelFit')
   local seed = 27
   torch.manualSeed(seed)
   math.randomseed(seed)
   
   
   local alphas = {{'a', 1, 1},
                   {'b', 1, 2},
                   {'c', 2, 1},  -- should be most accurate
                   {'d', 2, 2}}
   local nFolds = 3
   -- generate data
   local nObservations = 10
   xs = {}
   ys = {}
   for i = 1, nObservations do
      local x = torch.uniform(0, 1)
      local x = i
      local epsilon = torch.normal(0,.1)
      y = 2 * x + 1 + epsilon
      xs[#xs + 1] = x
      ys[#ys + 1] = y
   end
   v('all xs', xs)
   v('all ys', ys)
   
   -- make Tensors from xs and ys
   trainingXs = torch.Tensor(nObservations, 1)
   trainingYs = torch.Tensor(nObservations)
   for i = 1, nObservations do
      trainingXs[i][1] = xs[i]
      trainingYs[i] = ys[i]
   end

   local function modelFit(alpha, removedFold, kappa, 
                           trainingXs, trainingYs,
                           modelState, options)
      local v, isVerbose = makeVerbose(false, 'modelFit')
      verify(v, isVerbose,
             {{alpha, 'alpha', 'isTable'},
              {removedFold, 'removedFold', 'isNumber'},
              {kappa, 'kappa', 'isSequence'},
              {trainingXs, 'trainingXs', 'isTensor2D'},
              {trainingYs, 'trainingYs', 'isTensor1D'},
              {modelState, 'modelState', 'isTable'},
              {options, 'options', 'isTable'}})
      return alpha
   end

   local function modelUse(alpha, model, x, modelState, options)
      -- return the loss
      local v, isVerbose = makeVerbose(false, 'modelUse')
      verify(v, isVerbose,
             {{alpha, 'alpha', 'isTable'},
              {model, 'model', 'isTable'},
              {x, 'x', 'isTensor1D'},
              {modelState, 'modelState', 'isTable'},
              {options, 'options', 'isTable'}})
      
      local estimate = alpha[2] * x[1] + alpha[3]
      v('x, estimate', x, estimate)
      return true, estimate
   end -- useModel

   modelState = {}
   options = {}
   options.cvLoss = 'abs'

   local alphaStar, losses, coverage = crossValidation(alphas,
                                                       nFolds,
                                                       nObservations,
                                                       trainingXs,
                                                       trainingYs,
                                                       modelFit,
                                                       modelUse,
                                                       modelState,
                                                       options)
   v('alphaStar', alphaStar)
   v('losses', losses)
   v('coverage', coverage)
   for key, value in pairs(losses) do
      v('alpha', key)
      v('loss[alpha]', value)
      v('coverage[alpha]', coverage[key])
   end
   tester:asserteq('c', alphaStar[1])
end


tester:add(test)
local verbose = true
if verbose then
   print('****************************************************************')
end
tester:run(verbose)