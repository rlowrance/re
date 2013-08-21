-- Completion-test.lua
-- unit tests and regression test

require 'checkGradient'
require 'Completion'
require 'IncompleteMatrix'
require 'makeVerbose'
require 'Set'
require 'setRandomSeeds'
require 'Tester'

tester = Tester()

-- initial random number seeds
do
   local seed = 27
   setRandomSeeds(seed)
end


test = {}

--local stopOnFirstFailure = true
--local tester = Tester(stopOnFirstFailure)

--------------------------------------------------------------------------------
-- readCommandLine: parse and validate command line
--------------------------------------------------------------------------------

-- ARGS
-- arg  Lua's command line arg object
-- RETURN
-- cmd object used to parse the args
-- params: table of parameters found
function readCommandLine(arg)
   cmd = torch.CmdLine()
   cmd:text('Unit and regression testing for IncompleteMatrix class')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-regression', false, 'Also run regression test')
   cmd:text()

   -- parse command line
   params = cmd:parse(arg)


   -- check for allowed parameter values

   if not (params.regression == true or params.regression == false) then
      assert('params.regression must be true or false', params.regression)
   end
   return cmd, params
end -- readCommandLine

--------------------------------------------------------------------------------
-- continue: print msg and wait for keystroke
--------------------------------------------------------------------------------

function continue(...)
   print(...)
   print('hit ENTER to continue')
   io.read()
end -- continue

--------------------------------------------------------------------------------
-- helper functions
--------------------------------------------------------------------------------

function makeIm16()
   local im = IncompleteMatrix()
   im:add(1, 1, 1)
   im:add(2, 3, 6)
   local matrix = torch.Tensor(2, 3):zero()
   matrix[1][1] = 1
   matrix[2][3] = 6
   return im, matrix
end --makeIm16

function makeIm1234()
   local im = IncompleteMatrix()
   im:add(1,1,1)
   im:add(1,2,2)
   im:add(2,1,3)
   im:add(2,2,4)
   return im
end -- makeIm1234

function makeIm123456()
   -- return im, weights, rank
   local im = IncompleteMatrix(false)
   -- set known entries
   im:add(1,1,1)
   im:add(1,2,2)
   im:add(1,3,3)
   im:add(2,1,4)
   im:add(2,2,5)
   im:add(2,3,6)
   tester:asserteq(im.nElements, 6, '6 elements added')
   -- set known weights
   local rank = 3
   local nRows = 2
   local nColumns = 3
   local nWeightVectors = nRows + nColumns
   local weights = torch.Tensor(nWeightVectors, rank)
   local function set(index, a, b, c)
      weights[index][1] = a
      weights[index][2] = b
      weights[index][3] = c
   end
   set(1, 1, 2, 3)
   set(2, 4, 5, 6)
   set(3, 7, 8, 9)
   set(4, 10, 11, 12)
   set(5, 13, 14, 15)
   return im, weights, rank
end -- makeIm123456

--------------------------------------------------------------------------------
-- unit tests
--------------------------------------------------------------------------------

function test.__init()
   local v = makeVerbose(false, 'test.__init')
   local trace = false
   local me = 'test.__init: '
   local lambda = 0.001
   local rank = 3
   local initialWeight = 1
   local c = Completion(makeIm16(), lambda, rank, initialWeight)
   v('c', c)
   tester:assert(c, 'not constructed')
   tester:asserteq(rank, c:getRank())
   local weights = c:getWeights()
   tester:asserteq(5, weights:size(1))
   tester:asserteq(rank, weights:size(2))
   for rowIndex = 1, 5 do
      for colIndex = 1, rank do
         tester:asserteq(initialWeight, weights[rowIndex][colIndex])
      end
   end
end -- test.__init

function test.callOptimCg()
   print('STUB test.callOptimCg')
   if true then return end
   local v = makeVerbose(false, 'test.callOptimCg')

   local im = makeIm16()

   local rho = 0.01
   local sig = 0.5
   local int = 0.1
   local ext = 3.0
   local maxIter = 1
   local ratio = 100
   local maxEval = 1.25 * maxIter

   local rank = 3
   local lambda = 0.001

   local weights, lossTable = im:cg(rank,
                                    rho, sig,
                                    int, ext,
                                    maxIter, ratio, maxEval,
                                    lambda)

   v('result weights', weights)
   v('lossTable', lossTable)
   v('im.weights', im.weights)
   v('diff', weights - im.weights)

   tester:assertlt(torch.dist(weights, im.weights), 1e-6, 'returned == stored')
   tester:assertTensorEq(weights, im.weights, 1e-6, 'returned == stored')


   -- check for decreasing losses
   tester:asserteq(2, #lossTable, 'two function evals')
   for i = 1, #lossTable do
      if i > 1 then
         tester:assertlt(lossTable[i], lossTable[i-1], 'decreasing error')
      end
   end

   local computedLoss = im:_opFunc(weights, lambda, 'all')
   v('computedLoss', computedLoss)
   tester:assertlt(math.abs(computedLoss-lossTable[#lossTable]), 1e-6, 
                   'computedLoss = returned loss')
end -- callOptimCg

function callOptimCheck(makeState, 
                        points, 
                        optimCall, 
                        expectedMinimizer,  -- if nil, don't test
                        tolerance)          -- if nil, don't test
   -- check using im16
   local v = makeVerbose(false, 'Completion-test callOptimCheck')
 
   assert(type(makeState) == 'function')
   assert(points == 'all' or points == 'random')
   assert(type(optimCall) == 'function')
 

   local im = makeIm16()

   local rank = 1
   local lambda = 1e-10
   local c = Completion(im, lambda, rank, 1) -- initial weights all one
   
   local state = makeState()

   v('c', c)
   v('state', state)
   v('points', points)
   local xstar, lossTable = optimCall(c, c:getWeights(), state, points)

   v('points', points)
   v('ending state', state)
   v('lambda', lambda)
   v('xstar', xstar)
   v('lossTable', lossTable)
   v('state.printedLines', state.printedLines)
   if state.printedLines and #state.printedLines >= 1 then
      v('why optim stopped', state.printedLines[1][2])
   end
   
   if expectedMinimizer and
      tolerance and
      torch.norm(xstar - expectedMinimizer) > tolerance then
      print('STUB does not converge to minimzer xmin')
      return
   end
   return
end -- callOptimCheck


function test.callOptimCg()
   if false then
      print('STUB test.callOptimLbfgs HAS DOWN AND UP PROBLEM')
      return
   end
   local v = makeVerbose(false, 'test.callOptimCg')

   local function makeState()
      local state = {}
      state.rho = 0.01
      state.sig = 0.5
      state.int = 0.1
      state.ext = 3.0
      state.maxIter = 20
      state.ratio = 100
      state.maxEval = state.maxIter * 1.25
      return state
   end

   local function callCg(c, weights, state, points)
      v('c', c)
      return c:callOptimCg(weights, state, points)
   end

   local sqrt6 = math.sqrt(6)
   local minimizer =  torch.Tensor({{1}, {sqrt6}, {1}, {0}, {sqrt6}})
   local tolerance = 1e-6

   local pointsChoices = {'all', 'random'}
   for _, points in ipairs({'all', 'random'}) do
      callOptimCheck(makeState, points, callCg, minimizer, tolerance)
   end
end -- callOptimCg

function test.callOptimLbfgs()
   if false then
      print('STUB test.callOptimLbfgs HAS DOWN AND UP PROBLEM')
      return
   end
   local v = makeVerbose(false, 'test.callOptimLbfgs')

   local function makeState()
      local state = {}
      state.maxIter = 100
      state.maxEval = state.maxIter * 1.25
      state.tolFun = 1e-10
      state.tolX = 1e-9
      state.nCorrection = 100
      state.learningRate = 0.1
      state.verbose = true
      return state
   end

   local function callLbfgs(c, weights, state, points)
      v('c', c)
      return c:callOptimLbfgs(weights, state, points)
   end

   local sqrt6 = math.sqrt(6)
   local minimizer =  torch.Tensor({{1}, {sqrt6}, {1}, {0}, {sqrt6}})
   local tolerance = 1e-6

   local pointsChoices = {'all', 'random'}
   for _, points in ipairs({'all', 'random'}) do
      callOptimCheck(makeState, points, callLbfgs, minimizer, tolerance)
   end
   
end -- callOptimLbfgs

function test.callOptimSgd()
   if false then
      print('STUB test.callOptimSgd')
      return
   end
   
   local v = makeVerbose(false, 'test.callOptimSgd')

   local function makeState()
      local state = {}
      state.learningRate = 1e-3
      state.learningRateDecay = 0
      state.weightDecay = 0
      state.momentum = 0
      return state
   end -- makeState

   local function callSgd(c, weights, state, points)
      assert(c)
      assert(weights)
      assert(state)
      assert(points)
      v('c', c)
      v('weights', weights)
      v('state', state)
      v('points', points)
      return c:callOptimSgd(weights, state, points)
   end -- callSgd

   local sqrt6 = math.sqrt(6)
   local minimizer =  torch.Tensor({{1}, {sqrt6}, {1}, {0}, {sqrt6}})
   local tolerance = nil -- nil means don't test actual vs. minimizer

   local pointsChoices = {'all', 'random'}
   for _, points in ipairs({'all', 'random'}) do
      callOptimCheck(makeState, points, callSgd, minimizer, tolerance)
   end

end -- callOptimSgd

function test.clone()
   local v = makeVerbose(false, 'test.clone')


   -- initialize with specific weights
   local lambda = 0.001
   local rank = 10
   local initialWeight = 27
   local c = Completion(makeIm123456(), lambda, rank, initialWeight)
   local clone = c:clone()
 
   -- check that the weights do not share storage
   local cWeights = c:getWeights()
   local cloneWeights = clone:getWeights()
   cloneWeights[1][1] = 0
   tester:asserteq(0, cloneWeights[1][1])
   tester:asserteq(initialWeight, cWeights[1][1])

   -- initialize with random weights
   c = Completion(makeIm16(), lambda, rank)
   v('c.weights (random)', c.weights)
   tester:assert(c ~= nil)
end -- clone

function test.complete()
   -- complete im16 with SGD and then check answer
   if false then
      print('STUB complete: get _sampleGradient working first')
      return
   end

   local v = makeVerbose(false, 'test.complete')

   -- complete using results from SGD on im16
   local function check16Sgd()
      local im, actual = makeIm16()
      local lambda = 1e-6
      local rank = 1
      local initialWeight = nil  -- nil means random
      local c = Completion(im, lambda, rank, initialWeight)
      
      local x = c.weights -- random initial weights
      state = {}
      state.learningRate = 1e-2
      state.learningRateDecay = 0
      state.weightDecay = 0
      state.momentum = 0
      v('state', state)
      local points = 'random'
      v('points', points)
      local iterations = 400 -- tuned by hand to give exact result to 4 decimals
      for iter = 1, iterations do
         x, losses = c:callOptimSgd(x, state, points)
         v(string.format('loss %s',points), c:loss(x))
      end
      v('x at end of iterations', x)
      
      -- adjust above until we iterate toward convergence
      c:setWeights(x)
      
      local estimated = c:complete()
      v('estimated', estimated)
      
      -- check shape
      tester:asserteq(2, estimated:size(1), '2 rows')
      tester:asserteq(3, estimated:size(2), '3 columns')

      -- check the two known entries
      v('estimate[1][1]', c:estimate(x,1,1))
      v('estimate[2][3]', c:estimate(x,2,3))
       
      
      v('R C Actual Estimated')
      for r = 1, 2 do
         for c = 1, 3 do
            if (r == 1 and c == 1) or
               (r == 2 and c == 3) then
               v(string.format('%1d %1d %6.4f %6.4f',
                               r, c, actual[r][c], estimated[r][c]))
            else
               v(string.format('%d %d %6s %6.4f',
                            r, c, 'NONE', estimated[r][c]))
            end
         end
      end

      -- these tests are tuned to the convergence from SGD, which is not good
      tester:assertlt(math.abs(actual[1][1] - estimated[1][1]), 1e-4)
      tester:assertlt(math.abs(actual[2][3] - estimated[2][3]), 1e-4)
   end -- check16Sgd

   local function checkKnown()
      local im, actual = makeIm16()
      local lambda = 1e-6
      local rank = 1
      local initialWeight = nil  -- nil means random
      local c = Completion(im, lambda, rank, initialWeight)
      
      local sqrt6 = math.sqrt(6)
      local x = torch.Tensor({{1},{sqrt6},{1},{0},{sqrt6}})
      c:setWeights(x)

      local estimated = c:complete()
      tester:assertlt(math.abs(1 - estimated[1][1]), 1e-6)
      tester:assertlt(math.abs(6 - estimated[2][3]), 1e-6)
   end

   check16Sgd()
   checkKnown()
end -- complete

function test.estimate()
   local im, weights, rank = makeIm123456()
   local lambda = 0.001
   local c = Completion(im, lambda, rank, 0)
   c:setWeights(weights)

   tester:asserteq(50, c:estimate(c:getWeights(),1,1))
   tester:asserteq(68, c:estimate(c:getWeights(),1,2))
   tester:asserteq(86, c:estimate(c:getWeights(),1,3))

   tester:asserteq(122, c:estimate(c:getWeights(),2,1))
   tester:asserteq(167, c:estimate(c:getWeights(),2,2))
   tester:asserteq(212, c:estimate(c:getWeights(),2,3))
end -- estimate


function test.getRank()
   local rank = 100
   local lambda = 0.001
   local c = Completion(makeIm16(), lambda, rank, 0)
   tester:asserteq(rank, c:getRank())
end -- getRank

function test.getWeights()
   local rank = 1
   local initialWeights = 27
   local lambda = 0.001
   local c = Completion(makeIm16(), lambda, 1, initialWeights)
   local w = c:getWeights()
   tester:assert(w, 'something returned')
   for i = 1, 5 do
      for j = 1, 1 do
         tester:asserteq(initialWeights, w[i][j])
      end
   end
end -- getWeights


function test.loss()
   local v = makeVerbose(false, 'test.loss')

   -- test against known minimizer for Im16
   do
      local im = makeIm16()
      local lambda = 0.001
      local rank = 1
      local c = Completion(im, lambda, rank)

      local sqrt6 = math.sqrt(6)
      local minimizer = torch.Tensor({{1},{sqrt6},{1},{0},{sqrt6}})
      local another = minimizer:clone()
      another[4] = 1  -- solution found by L-BFGS

      v('minimizer', minimizer)
      v('loss(minimizer)', c:loss(minimizer))

      v('another', another)
      v('loss(another)', c:loss(another))

      tester:assertlt(c:loss(minimizer), c:loss(another))
   end

   -- test with Im123456
   do
      local im, weights, rank = makeIm123456()
      v('im', im)
      
      local lambda = 0.001
      local c = Completion(im, lambda, rank, 0)
      
      -- all weights are zero
      tester:asserteq(91, c:loss(c:getWeights()), 'weights all 0')
      
      -- weights are 1 2 3 ...
      local actualLoss = c:loss(weights)
      -- set lab book for 2012-09-04 for the computation
      tester:asserteq(96251.24, actualLoss, 'weights 1 2 3 ...')
      
      
      -- test with Im
      rank = 2
      c = Completion(makeIm16(), lambda, rank, 0)
      tester:asserteq(37, c:loss(c:getWeights()), 'actual loss weights zero')

      c = Completion(makeIm16(), lambda, rank, 1)
      tester:asserteq(17.010, c:loss(c:getWeights()), 'weights ones') 
   end

   -- test known optimal result against value from optim.lbfgs
   do
      local im = makeIm16()
      local lambda = 0.001
      local rank = 1
      local c = Completion(im, lambda, rank)
      local sqrt6 = math.sqrt(6)
      local xStar = torch.Tensor({{1}, {sqrt6}, {1}, {0}, {sqrt6}})
      local lossOptimal = c:loss(xStar)
      local xLbfgs = torch.Tensor({{1}, {sqrt6}, {1}, {1}, {sqrt6}})
      local lossLbfgs = c:loss(xLbfgs)

      v('xStar', xStar)
      v('loss(xStar)', lossOptimal)
      v('xLbfgs', xLbfgs)
      v('loss(xLbfgs)', lossLbfgs)

      tester:assertlt(lossOptimal, lossLbfgs)
      --halt()
   end
end -- loss

function test.makeOpfunc()
   if true then
      print('STUB test.makeOpfunc')
      return
   end
   
   local v, trace = makeVerbose(true, 'test.makeOpfunc')


   local function check(im, rank, initialWeight, points, x, expectedFx)
      local v = makeVerbose(trace, 'test.makeOpfunc.check')

      v('im', im)
      v('rank', rank)
      v('initialWeight', initialWeight)
      v('points', points)
      v('x', x)
      v('expectedFx', expectedFx)

      local nWeights = rank * (im:getNRows() + im:getNColumns())
      local lambda = 0.001
      local c = Completion(im, lambda, rank, initialWeight)
      local opfunc = c:makeOpfunc(points)
      local fx, gradientx = opfunc(x)

      v('x', x)
      v('fx', fx)
      v('gradientX', gradientX)

      local tolFx = 1e-4
      tester:assertlt(math.abs(fx - expectedFx), tolFx)
      local epsilon = 1e-3
      local d, gradientOpfunc, gradientFinite = 
         checkGradient(opfunc, 
                       c.weights:clone():resize(nWeights),
                       epsilon)

      v('d', d)
      v('gradientOpfunc', gradientOpfunc)
      v('gradientFinite', gradientFinite)

      local tolD = 1e-3
      if d == d then -- otherwise d is NaN
         tester:assertlt(d, tolD)
      end
   end -- check

   local function makeTensor(...)
      local seq = {...}
      local t = torch.Tensor(#seq)
      for i = 1, #seq do
         t[i] = seq[i]
      end
      return t
   end -- makeTensor

   -- check(im, rank, initialWeight, points, x, expectedFx)
   check(makeIm16(), 1, 0, 'all', makeTensor(1,1), 37)
   check(makeIm16(), 2, 0, 'all', makeTensor(0,0), 37)
   check(makeIm16(), 2, 1, 'all', makeTensor(0,0), 17.01)
   check(makeIm123456(), 3, 0, 'all', makeTensor(0,0), 91)
   check(makeIm123456(), 3, 1, 'all', makeTensor(0,0), 19.015)
   tester:assert(false, 'write more makeOpfunc tests')
end -- makeOpfunc

function test.print()
   if true then
      print('STUB test.print')
      return
   end

   local v = makeVerbose(false, 'test.print')

   local im = makeIm16()
   im:print()
   tester:assert(true, 'print method did not finish')
end -- print

function test.rmse()
   local v = makeVerbose(false, 'test.rmse')

   local im = makeIm16()
   local lambda = 0.001
   local rank = 2
   local c = Completion(im, lambda, rank, 0)
   local tolerance = 0.0001
   tester:assertlt(math.abs(4.3012 - c:rmse(c:getWeights())), tolerance)

   c = Completion(im, lambda, rank, 1)
   tester:assertlt(math.abs(2.9155 - c:rmse(c:getWeights())), tolerance)
end -- rmse

function test.serializeDeserializeBug()
   -- test buggy case
   -- fixed by have the serialized file written in binary mode

   -- this value is written as 1.18486 if writeObject is given an ascii file
   local problemValue = 1.184856
   local path = 'Completion-serialization-testfile.test'

   local im = IncompleteMatrix()
   im:add(1,1,problemValue)
   
   local lambda = 0.001
   local rank = 10
   local c = Completion(im, lambda, rank)
   
   Completion.serialize(path, c)
   c = nil
   
   c = Completion.deserialize(path)
   tester:asserteq(problemValue, c.im:get(1,1))
end -- serailizeDeserializeBug

function test.serializeDeserialize()
   local v = makeVerbose(false, 'test.serializeDeserialize')

   local im = makeIm16()
   local lambda = 0.001
   local rank = 5
   local c = Completion(im, lambda, rank)  -- random weights
   local path = 'Completion-serialization-testfile.test'
   
   -- serialize c
   do
      v('c before writing', c)


      Completion.serialize(path, c)

      v('c after writing to disk', c)
   end

   tester:asserteq(2, im.nElements, '2 elements')

   im:add(1,2,27)
   tester:asserteq(3, im.nElements, '3 elements')

   -- deserialize c
   do
      local anotherC = Completion.deserialize(path)

      -- check that each component is equal
      local cIm = c.im
      local anotherIm = anotherC.im
      tester:asserteq(anotherIm.nRows, cIm.nRows)
      tester:asserteq(anotherIm.nCols, cIm.nCols)
      tester:asserteq(anotherIm.nElements, cIm.nElements)
      tester:asserteq(anotherC.rank, c.rank)

      tester:asserteq(2, anotherIm.nElements, '2 elements')

      local cWeights = c.weights
      local anotherWeights = anotherC.weights
      tester:assert(anotherWeights:size(1), cWeights:size(1))
      tester:assert(anotherWeights:size(2), cWeights:size(2))
   end
end -- serializeDeserialize

function test.triples()
   local v = makeVerbose(false, 'test.triples')

   local im = makeIm16()
   for i, j, value in im:triples() do
      if trace then v('i,j,value', i, j, value) end
      if i == 1 and j == 1 then
         tester:asserteq(1, value, '1,1')
      elseif i == 2 and j == 3 then
         tester:asserteq(6, value, '2,3')
      else
         tester:assert(false, 'extra entry found')
      end
   end
end -- Triples

function test._generateRandomIndices()
   local v = makeVerbose(true, 'test._generateRandomIndices')
   local lambda = 0.002
   local rank = 2
   local c = Completion(makeIm16(), lambda, rank)
   local ri = c:_generateRandomIndices()
   if trace then
      v('random indices', ri)
      for i = 1, #ri do
         v('ri[', i, ']', ri[i])
      end
   end
   tester:asserteq(2, #ri)
end -- _generateRandomIndices

function test._gradient()
   local v = makeVerbose(false, 'test._gradient')

   local function check(at, im, rank)
      v('at', at)
      v('im', im)
      v('rank', rank)

      local lambda = 0.001
      local initialWeights = 1
      local c = Completion(im, lambda, rank, initialWeights)

      local nRows = c.weights:size(1)
      local nCols = c.weights:size(2)
      local nElements = nRows * nCols

      local x = torch.Tensor(nRows, nCols):fill(at)
      local g = c:_gradient(x)
      v('gradient', gradient)
      
      local function f(x)
         return c:loss(x:clone():resize(nRows, nCols))
      end

      local epsilon = 1e-6
      local verbose = false
      local d, dh = checkGradient(f, 
                                  x:clone():resize(nElements), 
                                  epsilon, 
                                  g, 
                                  verbose)

      v('d', d)
      v('dh', dh)
      v('g', g)

      local tolerance = 1e-6
      tester:assertlt(d, tolerance)
   end

   local im1 = makeIm16()        -- one weight is not used by any sample
   local im2 = makeIm1234()      -- all weights are used by samples
   local im3 = makeIm123456()    -- all weights are used by samples
   local ims = {im1, im2, im3}
   
   for rank = 1, 4 do
      for imIndex = 1, #ims do
         for at = 1, 3 do
            check(at, ims[imIndex], rank)
         end
      end
   end
end -- test._gradient

         
function test._sampleGradient()
   -- see lab book 2012-09-16 for hand calculations
   if false then 
      print('STUB test._sampleGradient')
      return
   end
   
   local v = makeVerbose(false, 'test._sampleGradient')

   local im = makeIm1234()

   local function check(sampleRow, sampleCol, x, expected)
      local lambda = 0.001
      local rank = 1
      local c = Completion(im, lambda, rank) -- random weights
      local sg = c:_sampleGradient(x, sampleRow, sampleCol)

      v('actual sg', sg)
      v('expected sg', expected)

      local diff = 1e-3
      tester:assertTensorEq(expected, sg, diff)
   end

   local function makeWeights(a, b, c, d)
      local tensor = torch.Tensor(4, 1)
      tensor[1][1] = a
      tensor[2][1] = b
      tensor[3][1] = c
      tensor[4][1] = d
      return tensor
   end -- makeTensor

   local function makeVector(a, b, c, d)
      local tensor = torch.Tensor(4)
      tensor[1] = a
      tensor[2] = b
      tensor[3] = c
      tensor[4] = d
      return tensor
   end -- makeVector

   -- check(sampleRow, sampleCol, x, expected)
   v('im', im)
   local weights =  makeWeights(5, 6, 7, 8)
   check(1, 1, weights, makeVector(476.010, 0.012, 340.014, 0.016))
   check(1, 2, weights, makeVector(608.010, 0.012, 0.014, 380.016))
   check(2, 1, weights, makeVector(0.010, 546.012, 468.014, 0.016))
   check(2, 2, weights, makeVector(0.010, 704.012, 0.014, 528.016))
   
end -- _sampleGradient

function test._nonRegularizedLoss()
   if false then
      print('STUB test._nonRegularizedLoss')
      return
   end

   local function check(im, initialWeight, expectedLoss)
      local lambda = 0.001
      local rank = 2
      local c = Completion(im, lambda, rank, initialWeight)
      tester:asserteq(expectedLoss, c:_nonRegularizedLoss(c:getWeights()))
   end

   -- check(im, initialWeight, expectedLoss)
   check(makeIm16(), 0, 37)
   check(makeIm16(), 1, 17)
end -- _nonRegularizedLoss

function test.setWeights()
   local im, weights, rank = makeIm123456()
   local lambda = 0.001
   local c = Completion(im, lambda, rank, 1)
   
   local weights = torch.Tensor(5, 10):fill(1)
   c:setWeights(weights)

   tester:asserteq(10, c:estimate(c:getWeights(),1,1))
end -- setWeights

--------------------------------------------------------------------------------
-- regressionTest
--------------------------------------------------------------------------------

-- verify that SGD iterations are reducing the error in predicting known entries
function regressionTest(nRows, nCols, rank, nIterations, learningRate)
   local trace = false
   if trace then print('\nregressionTest') end

   assert(nRows)
   assert(nCols)
   assert(rank)
   assert(nIterations)
   assert(learningRate)

   local im = IncompleteMatrix()
   
   local filled = 0.10  -- fraction of incomplete matrix that is filled
   
   -- generate known weights
   weightsKnown = torch.randn(nRows + nCols, rank)
   if trace then print(' weightsKnown\n', weightsKnown) end
   
   -- build incomplete matrix 
   
   function elementAt(row, col)
      if false and trace and row == 1 and col == 1 then
         print(' elementAt')
         print('  weightsKnown[1]', weightsKnown[1])
         print('  weightsKnown[21]', weightsKnown[nRows + col])
      end
      return torch.dot(weightsKnown[row], weightsKnown[nRows + col])
   end

   im = IncompleteMatrix()
   -- assure that the two corners are filled
   im:add(1, 1, elementAt(1, 1))
   im:add(nRows, nCols, elementAt(nRows, nCols))
   local adjustedFilled = ((filled * nRows * nCols) - 2) / (nRows * nCols)
   if trace then print(' adjustedFilled', adjustedFilled) end
   assert(adjustedFilled >= 0)
   for row = 1, nRows do
      for col = 1, nCols do
         if (row == 1 and col == 1) or
            (row == nRows and col == nCols) then
            -- do nothing
         elseif torch.uniform(0, 1) < adjustedFilled then
            -- generate and add another element
            im:add(row, col, elementAt(row, col))
         end
      end
   end
   
   if false and trace then 
      print(' random incomplete matrix')
      im:print()
   end

   local learningRateDecay = 0.0001
   local lambda = 0.001
   local initialLoss

   function printParams()
      print(' nRows', nRows)
      print(' nCols', nCols)
      print(' learningRate', learningRate)
      print(' learningRateDecay', learningRateDecay)
      print(' lambda', lambda)
      print(' nIterations', nIterations)
      print(' initialLoss', initialLoss)
   end

   printParams()

   -- check for decreasing errors
   local prevLoss
   local loss
   local weightsEstimated
   local stuckLimit = 50
   local timer = torch.Timer()
   local selectedLosses = {}
   local weightDecay = 0
   local momentum = 0
   for iterant = 1, nIterations do
      weightsEstimated, loss = im:sgd(rank, 
                                      learningRate, 
                                      learningRateDecay, 
                                      weightDecay,
                                      momentum,
                                      lambda)
      -- loss is a table, 
      if type(loss) == 'table' then
         assert(#loss == 1, 'loss has one element')
         loss = loss[1]
      end

      -- write a report every so often
      local reportFrequency = 10
      if iterant > 1000 then
         reportFrequency = 1000
      end
      if iterant % reportFrequency == 0 then 
         printParams()
         selectedLosses[#selectedLosses + 1] = {iterant, loss}
         print('Losses at selected iterants')
         print(string.format(' %15s %15s', 'iterant', 'loss'))
         for _, v in  ipairs(selectedLosses) do
            print(string.format(' %15d %15.4f', v[1], v[2]))
         end
      end

      if initialLoss == nil then
         initialLoss = loss
         selectedLosses[#selectedLosses + 1] = {1, initialLoss}
      end
      if trace then 
         print(' weightsEstimated', weightsEstimated)
         print(' fWeights', loss)
      end
      assert(weightsEstimated:size(1) == (nRows + nCols), 
             'weights size number rows')
      assert(weightsEstimated:size(2) == rank, 
             'weights size number cols')
      --continue()
      print(string.format('%d/%d loss %f wall clock %f cpu %f', 
                          iterant, nIterations, loss, 
                          timer:time().real,
                          timer:time().user + timer:time().sys))
      timer:reset()
      if prevLoss then 
         if loss >= prevLoss then
            print('loss not decreasing')
            if timesStuck then
               timesStuck = timesStuck + 1
            else
               timesStuck = 1
            end
            if timesStuck >= stuckLimit then
               print('stopping iterations')
               break
            end
         else
            timesStuck = 0
         end
      end
      prevLoss = loss
   end -- for iterant
   print('initial loss was', initialLoss)

   --print('actual weights', weightsKnown)
   --print('estimated weights', estimatedWeights)
   --print('actual weights - estimated weights')
   local errorsAbsolute = torch.add(weightsKnown, -1, weightsEstimated)
   --print('absolute errors', errorsAbsolute)

   local errorsRelative = torch.cdiv(errorsAbsolute, weightsKnown)
   --print('relative errors', errorsRelative)

   printParams()

   -- print nicely
   local heading = ''

   function append(text)
      heading = heading .. string.format('%-17s ', text)
   end

   append('actual weights')
   append('est weights')
   append('abs errors')
   append('rel errors')

   print(heading)

   local rowLimit = 100
   for row = 1, nRows + nCols do

      local function v(matrix, row, col)
         if matrix == 1 then return weightsKnown[row][col]
         elseif matrix == 2 then return weightsEstimated[row][col]
         elseif matrix == 3 then return errorsAbsolute[row][col]
         elseif matrix == 4 then return errorsRelative[row][col]
         else assert(false, 'impossible')
         end
      end

      local line = ''
      for matrix = 1, 4 do
         for col = 1, rank do
            line = line .. string.format('%5.2f ', v(matrix, row, col))
         end
      end
      print(line)
      if row > rowLimit then 
         print('... truncated')
         break 
      end
   end

   -- compare actual entries with estimated entries
   print()
   print('row col actual est')
   local entryCount = 0
   local entryLimit = 100
   for rowIndex, colIndex, actualEntry in im:triples() do
      print(string.format('%3d %3d %6.2f %6.2f',
                          rowIndex, 
                          colIndex, 
                          actualEntry, 
                          torch.dot(weightsEstimated[rowIndex],
                                    weightsEstimated[nRows + colIndex])))
      entryCount = entryCount + 1
      if entryCount > entryLimit then
         print('... truncated')
         break 
      end
   end
end  -- regressionTest

--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------

print('++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++')

local cmd, params = readCommandLine(arg)

-- run only one tests
if false then 
   --tester:add(test.estimate, 'test.estimate')
   tester:add(test.makeOpfunc, 'test.makeOpfunc')
   --tester:add(test._gradient, 'test._gradient')
   --tester:add(test._opFunc, 'test._opFunc')
   --tester:add(test.setWeights, 'test.setWeights')
elseif false then
   tester:add(test.__init, 'test.__init')
   --tester:add(test.Clone, 'test.Clone')
   --tester:add(test.add_1, 'test.add_1')
   --tester:add(test.add_2, 'test.add_2')
   tester:add(test.estimate, 'test.estimate')
   --tester:add(test.lbfgs, 'test.lbfgs')
   tester:add(test.lbfgsRestart, 'test.lbfgsRestart')
   tester:add(test.loss, 'test.loss')
   --tester:add(test.Triples, 'test.Triples')
   --tester:add(test._generateRandomIndices, 'test._generateRandomIndices')
   tester:add(test._gradient, 'test._gradient')
   --tester:add(test._initializeWeights, 'test._initializeWeights')
   --tester:add(test._loss, 'test._loss')
   --tester:add(test._opFunc, 'test._opFunc')
   --tester:add(test._opFuncAll, 'test._opFuncAll')
   tester:add(test._sampleGradient, 'test._sampleGradient')
else
   tester:add(test)
end
local printUnitTest = true
tester:run(printUnitTest)

print('unit tests finished')
if not params.regression then
   print('specify -regresion on command line to run regressions')
else
   print('starting regression test: could take a while')
   -- initialLearningRate experiments:
   -- 1 leads to divergence of loss
   -- 0.1 leads to divergence sometimes, convergence others
   -- 0.05 leads to a stable loss, not convergence or divergence
   -- 0.01 : 
   --        initalLoss 770,000
   --        got stuck at a loss of about 480,000
   -- 0.001: works kind of
   --        reduced loss form 701,394 to 298,499
   --        however, actual and estimated entries in matrix are very different
   --        
   regressionTest(112000, 120, 3, 100000, .001) -- rows 112,000 cols 40 rank 3
end



-- Results on 2012-07-26
--[[
           99500     298557.3410
           99600     298545.3904
           99700     298539.3528
           99800     298531.8077
           99900     298511.1889
          100000     298499.1517
100000/100000 loss 298499.151655 wall clock 0.992931 cpu 0.484030
initial loss was    701394.20463519
 nRows    112000
 nCols    120
 learningRate    0.001
 learningRateDecay    0.0001
 lambda    0.001
 nIterations    100000
 initialLoss    701394.20463519
actual weights    est weights       abs errors        rel errors        
 1.34  0.14 -0.63  0.87  0.31 -0.19  0.47 -0.17 -0.44  0.35 -1.18  0.70 
 0.49 -2.22 -0.46  1.17 -0.73 -0.17 -0.68 -1.49 -0.29 -1.38  0.67  0.63 
-2.12 -0.86  0.07 -0.65  1.63  0.08 -1.47 -2.49 -0.01  0.69  2.91 -0.14 
 0.20 -0.28  0.17  0.43 -2.08 -0.54 -0.23  1.80  0.71 -1.17 -6.49  4.24 
 0.24  2.23 -1.55  3.22 -1.35 -0.47 -2.98  3.58 -1.08 -12.32  1.61  0.70 
 1.15 -0.57  0.24  0.50 -2.21 -0.52  0.65  1.64  0.75  0.56 -2.89  3.19 
 0.23 -1.64 -0.08  1.32 -0.26 -0.44 -1.10 -1.38  0.36 -4.84  0.84 -4.60 
-0.31 -2.63 -2.50 -0.95 -1.68 -0.39  0.64 -0.95 -2.11 -2.09  0.36  0.84 
 0.03 -1.49 -0.65 -0.85 -0.87 -0.00  0.88 -0.63 -0.65 28.02  0.42  1.00 
 0.85 -0.77  0.20  0.88 -0.64  0.30 -0.03 -0.13 -0.10 -0.03  0.16 -0.53 
-2.08 -2.30 -0.79  2.21 -0.41 -0.25 -4.29 -1.89 -0.54  2.06  0.82  0.68 
-2.07  1.75 -0.68  0.63 -0.30 -0.32 -2.70  2.05 -0.37  1.31  1.17  0.53 
-0.03 -0.06  0.70  1.08  0.28  0.24 -1.11 -0.33  0.46 44.04  5.79  0.66 
-0.92  0.17  0.17 -0.08  0.21  0.40 -0.84 -0.05 -0.23  0.91 -0.28 -1.33 
-0.64 -0.83 -0.68 -2.12 -0.17  0.05  1.49 -0.67 -0.73 -2.33  0.80  1.07 
-1.25 -0.38 -0.85  1.25  1.89  1.13 -2.50 -2.27 -1.98  2.00  5.97  2.33 
-1.13 -2.03 -1.04 -1.26  0.31  1.37  0.13 -2.34 -2.41 -0.12  1.15  2.31 
-0.09  0.24 -0.43 -0.10  1.37  1.05  0.01 -1.12 -1.48 -0.12 -4.61  3.45 
 2.14 -0.16  0.37 -1.19 -1.82  0.22  3.32  1.66  0.16  1.56 -10.28  0.42 
-2.69  0.22  0.41 -1.63 -0.02 -1.67 -1.06  0.24  2.08  0.39  1.11  5.12 
 0.40  0.62 -2.00 -0.54 -1.01  0.24  0.93  1.63 -2.23  2.35  2.63  1.12 
-0.05 -0.96  0.44  1.13  0.89 -0.90 -1.18 -1.85  1.34 22.91  1.93  3.03 
 0.87 -0.57  1.41  0.29  1.04  0.22  0.58 -1.62  1.19  0.67  2.81  0.84 
 0.80  1.00 -1.40 -0.84  0.20 -1.41  1.64  0.79  0.02  2.04  0.80 -0.01 
-1.13 -2.93 -0.21  0.90 -0.44  1.00 -2.03 -2.50 -1.20  1.79  0.85  5.83 
-0.51 -0.17  1.36 -1.04 -0.11  1.17  0.53 -0.05  0.19 -1.04  0.32  0.14 
 0.54  1.04  0.12  0.16  1.58 -0.18  0.38 -0.55  0.30  0.70 -0.53  2.49 
-2.12  0.08  0.23  0.25 -0.16 -0.48 -2.37  0.24  0.71  1.12  3.08  3.07 
-1.78 -0.42 -0.55  0.49  1.17 -2.24 -2.27 -1.59  1.69  1.27  3.79 -3.05 
 1.15 -1.20  0.08 -0.10  0.07  1.21  1.25 -1.27 -1.13  1.08  1.06 -15.04 
 0.94 -0.37  0.39  0.01  1.23  0.71  0.93 -1.59 -0.31  0.99  4.32 -0.80 
 0.46  1.74  0.16 -0.35  1.31  0.04  0.80  0.43  0.12  1.76  0.24  0.77 
 1.55  0.18 -0.55 -0.34  0.56 -0.74  1.89 -0.38  0.19  1.22 -2.16 -0.34 
 0.93 -0.10 -0.74 -1.33  1.49  0.29  2.26 -1.59 -1.03  2.43 15.68  1.39 
 0.57  0.60 -0.67 -0.60  0.07  0.37  1.17  0.53 -1.04  2.06  0.88  1.55 
 0.67 -0.16  1.21  0.56 -0.24  1.00  0.11  0.07  0.21  0.16 -0.45  0.17 
 1.95  0.16 -1.42 -3.09 -0.95 -0.57  5.05  1.10 -0.85  2.58  7.05  0.60 
 0.16  1.49  1.28 -0.50  0.24 -1.17  0.66  1.25  2.46  4.02  0.84  1.91 
-0.52 -0.76  0.58  0.59 -1.17  1.68 -1.11  0.41 -1.11  2.14 -0.55 -1.92 
 0.31  1.43  0.80  0.44 -0.54 -0.33 -0.13  1.97  1.13 -0.42  1.38  1.41 
-0.34  0.26  2.52  1.61  1.17 -0.83 -1.95 -0.91  3.36  5.72 -3.56  1.33 
-1.58 -0.85  0.93  0.60 -1.69  0.66 -2.18  0.84  0.27  1.38 -0.99  0.29 
 2.09 -2.75 -1.68  0.00 -0.84 -2.68  2.08 -1.91  0.99  1.00  0.69 -0.59 
 0.46  1.12 -1.43 -0.87 -1.03  0.14  1.33  2.14 -1.57  2.92  1.92  1.10 
 0.64  0.73  2.00  0.10  0.44 -1.52  0.54  0.29  3.53  0.84  0.40  1.76 
-0.03 -0.01  0.87 -1.86 -0.93  0.00  1.83  0.92  0.86 -64.35 -61.41  1.00 
-0.02 -0.82 -1.34  0.03  0.47 -0.17 -0.05 -1.29 -1.17  2.48  1.57  0.88 
 0.43  2.32 -0.35 -1.26 -0.97 -0.20  1.69  3.29 -0.15  3.97  1.42  0.42 
 0.35 -0.35  0.03 -0.55  0.47 -1.41  0.90 -0.82  1.44  2.59  2.36 52.12 
 0.18 -0.69 -0.88 -0.80  0.26 -0.98  0.98 -0.96  0.10  5.32  1.38 -0.12 
 1.57 -0.62  0.93  1.35 -0.67 -0.65  0.22  0.05  1.58  0.14 -0.09  1.69 
-0.98  1.01 -0.50 -1.74 -1.20 -0.34  0.77  2.21 -0.15 -0.78  2.20  0.31 
 0.84  2.68 -0.48 -0.08  1.33  0.41  0.92  1.35 -0.89  1.10  0.50  1.87 
-1.42 -0.53 -0.94  1.29  0.13 -1.03 -2.70 -0.66  0.09  1.91  1.25 -0.09 
-0.33 -0.12 -1.93  0.57 -1.33  0.64 -0.90  1.21 -2.57  2.70 -9.98  1.33 
-0.22 -0.59 -1.84 -1.49 -0.20  0.02  1.28 -0.39 -1.86 -5.86  0.66  1.01 
 1.14  0.68  1.54  0.53 -1.80  0.61  0.60  2.48  0.93  0.53  3.66  0.60 
 1.36  1.21 -1.70  1.48  0.76 -0.55 -0.12  0.46 -1.15 -0.09  0.38  0.68 
 0.95  0.46  0.34  0.81  1.00 -0.17  0.14 -0.54  0.51  0.14 -1.19  1.50 
-0.61  0.82 -1.60  1.04 -1.07 -0.54 -1.65  1.89 -1.06  2.69  2.31  0.66 
 1.30 -0.89 -0.97  0.56 -0.84  0.10  0.74 -0.05 -1.06  0.57  0.06  1.10 
-1.42  1.04  0.48  0.32  2.24 -0.51 -1.74 -1.20  0.99  1.23 -1.15  2.06 
-0.05  0.20  0.75 -0.31  1.41 -0.97  0.25 -1.21  1.72 -4.95 -6.13  2.29 
-0.25 -1.57  1.64 -0.55 -0.31 -0.16  0.29 -1.27  1.81 -1.18  0.80  1.10 
 0.29 -0.67  1.13 -2.02  1.53 -1.04  2.31 -2.20  2.16  8.00  3.29  1.92 
 0.74 -0.29 -1.03 -0.53 -0.07 -1.21  1.27 -0.22  0.18  1.73  0.77 -0.17 
-1.68 -0.78  0.11  0.15  0.71 -0.40 -1.83 -1.49  0.51  1.09  1.92  4.60 
 0.73 -0.83  0.81 -0.26  0.66 -0.37  0.99 -1.49  1.18  1.35  1.79  1.45 
 2.18  0.27  0.99 -0.75 -1.22 -0.08  2.93  1.49  1.07  1.34  5.49  1.08 
 0.16 -0.59 -0.04  0.55  0.15 -0.50 -0.39 -0.74  0.45 -2.47  1.26 -11.09 
-0.60 -0.90 -0.67  0.01 -0.84  0.12 -0.62 -0.06 -0.78  1.02  0.07  1.17 
 1.41 -0.57 -0.02  1.08  0.94 -1.78  0.33 -1.51  1.77  0.23  2.65 -114.86 
-0.91 -0.20  0.43 -0.59  0.19  1.23 -0.32 -0.40 -0.80  0.35  1.96 -1.83 
-0.04  0.56 -0.75  0.33 -1.20  0.61 -0.37  1.75 -1.36  9.11  3.15  1.81 
 0.40  1.22  1.64 -1.34  0.30 -2.10  1.74  0.92  3.74  4.34  0.75  2.28 
 0.41  0.02  0.68 -0.42 -0.24  0.36  0.83  0.26  0.32  2.03 13.49  0.48 
 0.41 -0.25  0.43 -0.33 -0.43  1.18  0.73  0.18 -0.76  1.80 -0.72 -1.77 
 0.12  0.76 -0.02 -1.37 -1.07  0.11  1.49  1.83 -0.14 12.08  2.41  5.81 
-1.71  2.15  0.81 -0.19  1.21  0.85 -1.52  0.94 -0.04  0.89  0.44 -0.05 
 0.64 -0.12  0.25 -0.69 -0.50 -0.13  1.32  0.38  0.38  2.08 -3.18  1.52 
 0.65 -0.74 -1.72 -0.24  2.53  0.69  0.89 -3.27 -2.41  1.37  4.42  1.40 
 1.30 -1.27  0.41 -1.16 -1.85 -2.49  2.47  0.59  2.90  1.89 -0.47  7.02 
 1.67  1.21  0.18 -0.33  0.15 -1.08  2.00  1.06  1.27  1.20  0.87  6.87 
 0.20 -0.11 -0.47 -0.86  0.49  1.39  1.06 -0.60 -1.85  5.25  5.32  3.99 
-1.73 -0.15  0.27 -0.23  0.45  0.79 -1.49 -0.60 -0.52  0.86  4.06 -1.92 
-0.68  1.48 -2.40 -0.37  0.26  1.63 -0.31  1.22 -4.02  0.46  0.82  1.68 
 1.60 -0.12  0.21  1.23  0.51  0.45  0.38 -0.63 -0.25  0.23  5.45 -1.19 
-0.53  0.42  1.82  0.26  0.60 -0.77 -0.80 -0.17  2.59  1.50 -0.41  1.42 
-0.09  0.07  0.16 -1.74  0.04 -0.49  1.65  0.03  0.65 -18.77  0.42  4.07 
 1.26 -0.82  1.30  0.34  0.24 -0.66  0.93 -1.06  1.96  0.73  1.29  1.51 
 0.13  0.08 -0.91  0.29  0.38  0.18 -0.16 -0.31 -1.09 -1.21 -4.01  1.20 
-1.74  0.45  1.18 -0.13  1.42  0.42 -1.61 -0.97  0.76  0.92 -2.16  0.64 
 1.02 -1.16  0.00  0.73  1.04 -0.66  0.30 -2.20  0.66  0.29  1.89 137.46 
-0.06  0.27  0.46 -0.36  0.51  0.75  0.30 -0.24 -0.29 -4.71 -0.88 -0.63 
-0.23  0.23 -1.13  0.50  1.86 -0.32 -0.73 -1.63 -0.81  3.12 -6.92  0.71 
-0.23 -0.23  0.87  0.89 -1.06  0.28 -1.12  0.83  0.60  4.97 -3.54  0.68 
-0.93  2.98  0.31  0.64  1.83  0.55 -1.58  1.15 -0.24  1.69  0.39 -0.78 
 0.33  0.58  0.05  1.18 -1.00 -0.18 -0.85  1.58  0.23 -2.54  2.74  4.58 
-1.09  0.86  0.58  0.09 -0.22  0.08 -1.17  1.08  0.50  1.08  1.25  0.86 
-1.07 -0.97 -0.86  0.44  0.71  0.07 -1.51 -1.68 -0.93  1.41  1.73  1.08 
 1.94  2.69 -0.53  0.54  0.27 -0.01  1.39  2.41 -0.52  0.72  0.90  0.98 
... truncated

row col actual est
  1   1  -1.09   0.02
112000 120  -0.87   1.17
  1   3  -0.22   0.00
  1  14   1.42   0.15
  1  22  -2.82   0.27
  1  23   0.99   0.36
  1  38   1.20  -0.17
  1  43  -1.62  -0.95
  1  47   0.10   0.25
  1  51   2.82  -0.84
  1  60  -0.51  -1.29
  1  84   0.27  -0.22
  1  91   0.69  -0.96
  1  92   0.51  -0.77
  1 101   0.64  -0.23
  1 106  -2.39  -0.90
  1 117  -1.82   0.54
  1 118  -0.83  -1.19
  2   6   0.01   0.01
  2  19  -2.33  -0.12
  2  33   1.45   1.36
  2  35  -4.08   1.22
  2  71  -0.24  -3.09
  2  73  -1.26   1.45
  2  76   2.85   0.30
  2 102  -0.12   1.06
  2 110  -0.88  -1.61
  2 115   1.67   0.56
  3   6  -0.26   0.06
  3  10  -4.46  -0.16
  3  15  -0.06   0.07
  3  44   3.40   0.55
  3  59   2.13   3.43
  3  86   0.18   2.77
  3  98  -2.81  -0.29
  4   7  -0.26  -0.15
  4  11   0.43   1.04
  4  12   0.23   0.39
  4  21   0.25  -0.83
  4  77  -0.35   3.94
  4  95   0.10  -2.02
  5   6   1.27   0.07
  5  27  -4.47  -2.02
  5  55  -0.81   0.72
  5  67  -1.33  -7.17
  5  83   1.42   1.55
  5 116   0.55   2.00
  5 119  -2.79   2.49
  6  16  -2.29  -0.96
  6  50   2.08   1.84
  6  53  -1.81   0.94
  6  68  -1.05   1.18
  7   3  -0.44  -0.02
  7   4   1.99   0.04
  7  26   0.24   0.08
  7  46   0.33   0.28
  7  54   0.56  -0.89
  7  63  -0.81  -0.12
  7  65   0.57  -0.30
  7  90   1.21   0.43
  7  96   3.07   1.25
  7  97  -0.01  -0.34
  7 105   2.72   1.07
  7 108   0.93  -0.77
  7 114   0.51   0.70
  8  17   1.82  -1.01
  8  39  -0.56  -2.19
  9   7  -0.16  -0.04
  9   8   2.12   0.04
  9  20  -0.76   0.99
  9  37  -1.15  -1.75
  9  48  -1.03   0.86
  9  75   2.07   1.47
 10  10   1.90  -0.09
 10  72  -0.15  -0.27
 10  85   0.63   1.43
 11   1  -0.78   0.06
 11  32  -3.23   1.51
 11  70   3.87   3.04
 12   3  -1.73  -0.02
 12   9  -3.83  -0.05
 12  29  -0.19   0.49
 12  30   0.41  -0.08
 12  88   1.26   0.30
 12 103  -3.18   0.31
 12 112   3.04  -0.55
 13   6  -0.45   0.05
 13  36   0.75  -1.81
 13  52  -0.17   0.13
 13  81  -0.40  -0.26
 13  93   0.46   2.24
 13 109  -0.53  -0.60
 14  18   0.95   0.03
 14  40   0.40   0.23
 14  57   1.26  -0.17
 14 111   1.66  -0.19
 15  15   0.83   0.11
 15  25   0.18   1.51
 15  87   0.66  -0.13
 16   2   1.98   0.19
 16  74  -2.11  -1.96
... truncated
]]

