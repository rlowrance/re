-- cvLoss-test.lua
-- unit test

require 'all'

test = {}
tester = Tester()

function test.lowCoverage()
   -- return error condition if cannot estimate

   torch.class('LowCoverageModel')
   function LowCoverageModel:__init()
   end

   function LowCoverageModel:estimate(query, alpha)
      return false, 'dk'
   end

   local function makeFittedModel(fold, kappa, alpha,
                                  trainingXs, trainingYs, 
                                  extraArg, options)
      return LowCoverageModel()
   end -- makeFittedModel
   
   local nObs = 5
   local nDims = 2
   local trainingXs = torch.rand(nObs, nDims)
   local trainingYs = torch.rand(nObs)
   local alpha = 1
   local i = 1
   local kappa = {1,2,3}
   local options = {}
   options.cvLoss = 'abs'
   local cvLoss = CvLoss(trainingXs, trainingYs, options)
   local ok, estimate = cvLoss:run(alpha, i, kappa,
                                   makeFittedModel, nil)
   tester:assert(not ok)
   tester:asserteq('dk', estimate)
end

function test.knn()
   local v = makeVerbose(true, 'test.knn')
   setRandomSeeds()

   
   --local function makeFittedModel(alpha, globalObsIndex, kappa, extraArg)
   local function makeFittedModel(fold, kappa, alpha,
                                  trainingXs, trainingYs,
                                  extraArg,
                                  options)
      local v = makeVerbose(false, 'makeFittedModel')
      v('fold', fold)
      v('kappa', kappa)
      v('alpha', alpha)
      v('trainingXs', trainingXs)
      v('trainingYs', trainingYs)
      v('extraArg', extraArg)
      v('options', options)

      affirm.isIntegerPositive(fold, 'fold')
      affirm.isSequence(kappa, 'kappa')
      affirm.isIntegerPositive(alpha, 'alpha')
      affirm.isTensor2D(trainingXs, 'trainingXs')
      affirm.isTensor1D(trainingYs, 'trainingYs')
      affirm.isTable(extraArg, 'extraArg')
      affirm.isTable(options, 'options')

      -- make the fitted model xs and ys
      local function notInFold(i)
         return kappa[i] ~= fold
      end

      -- determine number of observations not in the fold
      local modelNObs = 0
      for i = 1, #kappa do
         if notInFold(i) then
            modelNObs = modelNObs + 1
         end
      end

      if fold == 1 then tester:asserteq(6, modelNObs)
      else              tester:asserteq(7, modelNObs)
      end

      -- make subsets of observations not in fold
      -- these will be used for training purposes
      local modelXs = torch.Tensor(modelNObs, trainingXs:size(2))
      local modelYs = torch.Tensor(modelNObs)

      local modelObsIndex = 0
      for i = 1, #kappa do
         if notInFold(i) then
            modelObsIndex = modelObsIndex + 1
            modelXs[modelObsIndex] = trainingXs[i]
            modelYs[modelObsIndex] = trainingYs[i]
         end
      end
      
      v('fold', fold)
      v('modelXs', modelXs)
      v('modelYs', modelYs)
 
      -- these tests depend on knowing kappa
      local function testYs(seq)
         for i, expected in ipairs(seq) do
            tester:asserteq(seq[i], modelYs[i])
         end
      end

      if fold == 1 then 
         -- just test the Ys
         testYs({20, 30, 40, 70, 80})
      elseif fold == 2 then
         testYs({10, 40, 50, 60, 70, 90, 100})
      elseif fold == 3 then
         testYs({10, 20, 30, 50, 60, 80, 90})
      end

      v('extraArg.maxK', extraArg.maxK)
      local model = Knn(modelXs, modelYs, extraArg.maxK)
      v('model', model)
      -- no training to do
      return model
   end -- makeFittedModel


   local alphas = {1, 2}
   local data = {}
   local nObs = 10
   local nDims = 3
   local xs = torch.Tensor(nObs, nDims)
   local ys = torch.Tensor(nObs)
   for i = 1, nObs do
      ys[i] = 10 * i
      for j = 1, nDims do
         xs[i][j] = i
      end
   end


   extraArg = {}
   extraArg.nObs = nObs
   extraArg.nDims = nDims
   extraArg.xs = xs
   extraArg.ys = ys
   extraArg.maxK = 2
   makeFittedModelExtraArg = extraArg

   local options = {}
   options.cvLoss = 'abs'

   local cvLoss = CvLoss(xs, ys, options)

   local function cvLossFunction(alpha, i, kappa)
      local v = makeVerbose(false, 'cvLossFunction')
      local ok, loss = cvLoss:run(alpha, i, kappa, 
                                  makeFittedModel, makeFittedModelExtraArg)
      v('alpha', alpha)
      v('i', i)
      v('kappa', kappa)
      v('ok', ok)
      v('loss', loss)
      tester:assert(ok)
      local fold = kappa[i]
      v('fold', fold)
      -- see lab book 2012-10-03 for hand calculations
      if fold == 1 and alpha == 1 then
         tester:asserteq(10, loss)

      elseif fold == 1 and alpha == 2 then
         if i == 1 then tester:asserteq(15, loss)
         elseif i == 5 then tester:assert(loss == 5 or loss == 15)
         elseif i == 6 then tester:assert(loss == 5 or loss == 15)
         elseif i == 9 then tester:asserteq(0, loss)
         else error('bad i = ' .. tostring(i))
         end
            
      elseif fold == 2 and alpha == 1 then
         tester:asserteq(10, loss)

      elseif fold == 2 and alpha == 2 then
         if i == 2 then tester:asserteq(5, loss)
         elseif i == 3 then tester:assert(loss == 5 or loss == 15)
         elseif i == 8 then tester:asserteq(0, loss)
         else error('bad i = ' .. tostring(i))
         end

      elseif fold == 3 and alpha == 1 then
         tester:asserteq(10, loss)

      elseif fold == 3 and alpha == 2 then
         if i == 4 then tester:asserteq(0, loss)
         elseif i == 7 then tester:asserteq(0, loss)
         elseif i == 10 then tester:asserteq(15, loss)
         else error('bad i = ' .. tostring(i))
         end

      else
         error('bad alpha = ' .. tostring(alpha))
      end
      return loss
   end -- makeFittedModel

   local nFold = 3
   local alphaStar, lossTable = crossValidation(alphas,
                                                cvLossFunction,
                                                nFold,
                                                nObs)
   v('alphaStar', alphaStar)
   v('lossTable', lossTable)
   tester:asserteq(2, alphaStar)
end -- test.knn

tester:add(test)
tester:run(true) -- true ==> verbose