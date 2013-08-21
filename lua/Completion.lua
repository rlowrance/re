-- Completion.lua
-- complete an IncompleteMatrix

--require 'torch'

require 'optim'

require 'checkGradient'
require 'IncompleteMatrix'
require 'Set'
require 'shuffleSequence'
require 'sortedKeys'
require 'TimerCpu'

-- API overview
if false then
   -- constructing
   im = IncompleteMatrix()
   c = Completion(im:clone(), lambda, rank, initialWeightOption)
   clone = c:clone()  -- share nothing copy

   -- learning the weights by performing one iteration of an optimization algo
   -- lambda : number, coefficient of the regularizer
   -- points : string, either 'all' or 'random'
   --          whether gradient is evaluated at all known points of the
   --          IncompleteMatrix or at a single random known point
   -- state  : table, specific to the learning algorithm
   --          follows Koray's optim function of the same name
   xstar, lossTable = c:callOptimCg(x, state, points)
   xstar, lossTable = c:callOptimLbfgs(x, state, points)
   xstar, lossTable = c:callOptimSgd(x, state, points)

   -- determining error using specified weights and all sample points
   loss = c:loss(weights)  -- uses self.lambda as regularizer coefficient
   rmse = c:rmse(weights)  -- does not use the regularizer

   -- interfacing with Koray's optim opfunc
   opfunc = c:makeOpfunc(points) -- point in {all, random, {rowIndex, colIndex}
   fx, gradientX = opfunc(x)     -- return f(x), gradient(x) at points

   -- access the estimated matrix
   x = c:estimate(weights, rowIndex, colIndex)
  
   -- getters and setters
   n = c:getRank()

   tensor = c:getWeights()
   c:_setWeights(weights)

   -- printing
   c:print()

   -- reading and writing the entire instance
   Completion.serialize('path/to/file', c)     -- class method
   c = Completion.deserialize('path/to/file')  -- class method

   -- using the weights
   value = c:estimate(rowIndex, colIndex)  -- estimate one entry
   tensor = c:complete()                   -- estimate each entry

   -- major private methods (for testing and support of public methods)
   tensor = c:_gradient(weights)  -- gradient at weights using all sample points
   loss = c:_nonRegularizedLoss(weights)
   loss, gradient = c:_opFunc(lambda, points)-- DELETE THIS METHOD
end -- API overview

-----------------------------------------------------------------------------
-- construction
-----------------------------------------------------------------------------

local Completion = torch.class('Completion')

function Completion:__init(im, lambda, rank, initialWeight)
   -- ARGS
   -- im            : an Completion
   -- lambda        : number >= 0, coefficient of the L2 regularizer
   -- rank          : number > 0; integer rank of the solution
   -- initialWeight : optional number
   --                 if present, every weight is set to initialWeight
   --                 if absent, weights are randomly initialized
   -- RETURNS new Completion instance such that
   --   self.im shares storage with im
   --   call Completion(im:clone(), rank, initialWeight) to avoid sharing
   
   -- type and value check
   self:_checkIncompleteMatrix(im, 'im')

   self:_checkNonNegative(lambda, 'lambda')
   assert(lambda < 1, 'the regularizer coeeficient is usually small')

   self:_checkPositiveInteger(rank, 'rank')

   if initialWeight ~= nil then
      assert(type(initialWeight) == 'number', 'initialWeights not a number')
   end

   self.im = im:clone()
   self.lambda = lambda
   self.rank = rank
   if initialWeight == nil then
      self.weights = self:_generateWeightsRandom(im:getNRows(),
                                                 im:getNColumns(),
                                                 rank,
                                                 im:averageValue())
   else
      self.weights = self:_generateWeightsKnown(im:getNRows(),
                                                im:getNColumns(),
                                                rank,
                                                initialWeight)
   end
end -- __init


function Completion:callOptimCg(x, state, points)
   -- call optim.lbfgs after constructing a suitable opfunc
   -- ARGS:
   -- x                 : 2d Tensor, initial weights
   -- state             : table, passed to optim.lbfgs without modification
   -- points            : string, which point to evaluate opFunc at
   --                     oneOf{all, random}
   -- RETURNS what optim.lbfgs returns:
   -- x*                : value of x at end of 1 or more iterations
   -- tableLosses       : table of numbers
   --                     table[1] == loss before the weights were updated
   --                     table[#table] == loss on final evaluation
   -- MUTATES
   -- state             : table, mutated by optim.cg
   -- ref: https://github.com/koraykv/optim/blob/master/lbfgs.lua

   local v = makeVerbose(false, 'Completion:callOptimCg')
   
   local function checkCgState(state) 
      -- optim.cg does minimal checking, so check all state fields provided
      if state.rho ~= nil then
         self:_checkPositive(state.rho, 'state.rho')
      end
      if state.sig ~= nil then
         self:_checkPositive(state.sig, 'state.sig')
      end
      if state.int ~= nil then
         self:_checkPositive(state.int, 'state.int')
      end
      if state.ext ~= nil then
         self:_checkPositive(state.ext, 'state.ext')
      end
      if state.maxIter ~= nil then
         self:_checkPositive(state.maxIter, 'state.maxIter')
      end
      if state.ratio ~= nil then
         self:_checkPositive(state.ratio, 'state.ratio')
      end
      if state.maxIter ~= nil then
         self:_checkPositive(state.maxIter, 'state.maxIter')
      end
      if state.maxEval ~= nil then
         self:_checkPositive(state.maxEval, 'state.maxEval')
      end
   end

   return self:_callOptim(x, state, points, checkCgState, optim.cg)
end -- callOptimCg


function Completion:callOptimLbfgs(x, state, points)
   -- call optim.lbfgs after constructing a suitable opfunc
   -- ARGS:
   -- x                 : 2d Tensor, initial weights
   -- state             : table, passed to optim.lbfgs without modification
   -- points            : string, which point to evaluate opFunc at
   --                     oneOf{all, random}
   -- RETURNS what optim.lbfgs returns:
   -- x*                : value of x at end of 1 or more iterations
   -- tableLosses       : table of numbers
   --                     table[1] == loss before the weights were updated
   --                     table[#table] == loss on final evaluation
   -- MUTATES
   -- state             : table
   --                     add whatever optim.lbfgs adds
   --                     also add whatever optim.lbfgs printed
   -- ref: https://github.com/koraykv/optim/blob/master/lbfgs.lua

   local v = makeVerbose(false, 'Completion:callOptimLbfgs')
   
   local function checkLbfgsState(state)
      -- optim.lbfgs does minimal checking, so check all state fields provided
      if state.learningRate ~= nil then
         self:_checkPositive(state.learningRate, 'state.learningRate')
      end
      if state.maxIter ~= nil then
         self:_checkPositive(state.maxIter, 'state.maxIter')
      end
      if state.maxEval ~= nil then
         self:_checkPositive(state.maxEval, 'state.maxEval')
      end
      if state.tolFun ~= nil then
         self:_checkPositive(state.tolFun, 'state.tolFun')
      end
      if state.nCorrection ~= nil then
         self:_checkNonNegative(state.nCorrection, 'state.nCorrection')
      end
      if state.learningRate ~= nil then
         self:_checkPositive(state.learningRate, 'state.learningRate')
      end
      if state.verbose ~= nil then   -- optional state field
         self:_checkBoolean(state.verbose, 'state.verbose')
      end
   end

   return self:_callOptim(x, state, points, checkLbfgsState, optim.lbfgs)
end -- callOptimLbfgs


function Completion:callOptimSgd(x, state, points)
   -- call optim.sgd after constructing a suitable opfunc
   -- ARGS:
   -- x                 : 2d Tensor, initial weights
   -- state             : table, passed to optim.lbfgs without modification
   -- points            : string, which point to evaluate opFunc at
   --                     oneOf{all, random}
   -- RETURNS what optim.lbfgs returns:
   -- x*                : value of x at end of 1 or more iterations
   -- tableLosses       : table of numbers
   --                     table[1] == loss before the weights were updated
   --                     table[#table] == loss on final evaluation
   -- MUTATES
   -- state             : table, mutated by optim.sgd
   -- ref: https://github.com/koraykv/optim/blob/master/sgd.lua
   
   local v = makeVerbose(false, 'Completion:callOptimSgd')
   local timing = true -- determine and print CPU time
   local tc
   if timing then
      tc = TimerCpu()
   end

   assert(x, 'x is missing')
   assert(state, 'state is missing')
   assert(points, 'point is missing')

   local function checkSgdState(state)
      -- optim.sgd does minimal checking, so check all state fields provided
      if state.learningRate ~= nil then
         self:_checkPositive(state.learningRate, 'state.learningRate')
      end
      if state.learningRateDecay ~= nil then
         self:_checkNonNegative(state.learningRateDecay, 
                                'state.learningRateDecay')
      end
      if state.weightDecay ~= nil then
         self:_checkNonNegative(state.weightDecay, 'state.weightDecay')
      end
      if state.momentum ~= nil then
         self:_checkNonNegative(state.momentum, 'state.momentum')
      end
      if state.learningRates ~= nil then
         self:_checkTensor(state.learningRates, 'state.learningRates')
      end
      if state.evalCounter ~= nil then
         self:_checkNonNegative(state.evalCounter, 'state.evalCounter')
      end
   end

   local xStar, table = 
      self:_callOptim(x, state, points, checkSgdState, optim.sgd)

   if timing then
      v('Cpu seconds', tc:cumSeconds())
   end

   return xStar, table
end -- callOptimSgd


function Completion:clone()
   -- return a share-nothing Incomplete Matrix with identical values as self

   -- constuct new Completion
   local new = torch.factory('Completion')()
   
   -- establish self.im, self.rank
   new:__init(self.im:clone(), self.lambda, self.rank, 0)

   -- establish self.weights
   new.weights = self.weights:clone()

   return new
end -- clone

function Completion:complete()
   -- return the completed matrix as a 2D Tensor using the current weights
   local v = makeVerbose(false, 'Completion:complete')
   v('self.weights', self.weights)
   v('self.im', self.im)

   local nRows = self.im:getNRows()
   local nCols = self.im:getNColumns()
   v('nRows,nCols', nRows, nCols)

   local result = torch.Tensor(nRows, nCols)
   for r = 1, nRows do
      for c = 1, nCols do
         result[r][c] = self:estimate(self.weights, r, c)
      end
   end
   v('result', result)
   return result
end -- complete

function Completion.deserialize(path)
   -- return Completion object in file path
   -- NOTE: class method

   local trace = false
   local me = 'Completion.deserialize: '

   -- type and value check
   assert(path)
   assert(type(path) == 'string')

   local file = torch.DiskFile(path, 'r')
   assert(file, 'could not open file: ' .. path)
   -- use binary mode, as the serialization file was written this wasy
   file:binary()    
   
   
   local obj = file:readObject()

   -- verify that a 2D Tensor was read
   if trace then 
      print(me .. 'typename(obj)', torch.typename(obj)) 
   end
   assert(torch.typename(obj) == 'Completion',
          'file object not an Completion')

   file:close()
   
   return obj -- return a Completion object
end -- deserialize

function Completion:estimate(weights, rowIndex, colIndex)
   -- return estimate for the entry at [rowIndex][colIndex] using the weights
   -- ARGS
   -- weights  : 2D Tensor
   -- rowIndex : positive integer
   -- colIndex : positive integer
   -- RETURNS
   -- estimate : number

   local trace = false
   local me = 'Completion:estimate '

   assert(weights, 'weights missing')
   assert(rowIndex, 'rowIndex missing')
   assert(colIndex, 'colIndex missing')

   self:_checkWeights(weights, 'weights')

   local testUppserBound = true
   self:_checkIndices(rowIndex, colIndex, testUpperBound)

   local result = torch.dot(weights[rowIndex],
                            weights[self.im:getNRows() + colIndex])
   if trace then
      print(me .. 'rowindex, colIndex', rowIndex, colIndex)
      print(me .. 'row weights') print(weights[rowIndex])
      print(me .. 'col weights') print(weights[im:getNRows() + colIndex])
      print(me .. 'result', result)
   end
   return result
end -- estimate

function Completion:getRank()
   return self.rank
end

function Completion:getWeights()
   return self.weights
end


function Completion:loss(weights)
   -- return the loss for the weights and regularizer coefficient
   -- using all the samples
   -- ARGS: 
   -- weights : 2D Tensor of weights
   
   local me = 'Completion:loss'
   local v = makeVerbose(false, me)
   local timing = false
   
   local tc
   if timing then tc = TimerCpu() end

   local function elapsed(msg)
      if timing then
         print(me .. ': elapsed CPU to ' .. msg, tc:cumSeconds())
      end

   v('weights', weights)
   v('self', self)
   end

   self:_checkWeights(weights, 'weights')

   elapsed('about to compute nonRegularized loss')
   local nonRegularizedLoss = self:_nonRegularizedLoss(weights)

   -- compute the regularizer
   elapsed('about to compute the regularizer')
   -- compute regularizer
   local sumSquaredWeights = torch.sum(torch.cmul(weights, weights))
   
   local regularizer = self.lambda * sumSquaredWeights
   
   local loss = nonRegularizedLoss + regularizer

   if trace then
      v('nonRegularizedLoss', nonRegularizedLoss)
      v('sumSquaredWeights', sumSquaredWeights)
      v('regularizer', regularizer)
      v('loss', loss)
   end
   
   elapsed('about to return')
   return loss
   
end -- loss

function Completion:makeOpfunc(points)
   -- return an opfunc that satisifies the API for Koray's optim functions
   -- namely 
   --   fx, gradientx = opfunc(x)
   -- ARGS
   -- points : string or sequence
   --          if points == 'all', gradient is evaluated at all known points
   --             in im
   --          if points == 'random', gradient is evaluated at a single
   --             randomly-selected known point in im
   --          if points == {rowIndex, colIndex}, gradient is evaluated at the
   --             specified point
   -- RETURNS
   -- opfunc : function such that fx, gradientx = opfunc(x)
   --          ARG x is a 1D tensor
   --          RETURNED fx is a number
   --          RETURNED gradientx is a 1D tensor
   
   local v, trace = makeVerbose(false, 'Completion:makeOpfunc')
   local timing = false
   
   local tc
   if timing then
      tc = TimerCpu()
   end
   
   
   v('points', points)
   
   -- validate points
   if type(points) == 'string' then
      assert(points == 'all' or points == 'random')
   else
      assert(type(points) == 'table')
      assert(#points == 2)
   end
   
   -- prepare variables needed if points == 'random'
   local randomizedIndices, randomPosition
   if points == 'random' then
      randomizedIndices = self:_generateRandomIndices()
      randomPosition= 1
      if false and trace then
         v('randomizedIndices ssize', randomizedIndices:size())
         for i = 1, #randomizedIndices do
            v('randomized index', randomizedIndices[i])
         end
      end
   end


   -- prepare variables needed if points is a sequence
   local rowIndex, colIndex
   if type(points) == 'table' then
      rowIndex = points[1]
      colIndex = points[2]
   end
   
   local nRows = self.weights:size(1)
   local nCols = self.weights:size(2)
   local nElements = nRows * nCols
   v('nRows, nCols, nElements', nRows, nCols, nElements)

   local cumTc = TimerCpu()

   local function returnedOpfunc(x)
      -- opfunc(x) returns [xStar, gradient]
      -- NOTE: when points == 'random' most of the CPU time is spent
      --       in calculating the loss
      
      local me = 'Completion: returnedOpfunc'
      local v = makeVerbose(false, me)
      local timing = false
      local writeProgress = true

      local tc
      if timing then tc = TimerCpu() end

      local function elapsed(msg)
         if timing then
            print(me .. ': elapsed CPU to ' .. msg, tc:cumSeconds())
         end
      end

      elapsed('just starting')

      --v('x size', x:size())
      v('points', points)

      assert(torch.typename(x) == 'torch.DoubleTensor')

      x:resize(nRows, nCols)
      
      -- determine loss at all samples
      elapsed('before loss calculation')
      local loss = self:loss(x:resize(nRows, nCols))
      elapsed('after loss calculation')

      v('returned loss before step', loss)
      
      -- determine gradient at specified points
      local gradient
      if points == 'all' then
         gradient = self:_gradient(x)
      elseif points == 'random' then
         -- select the random row and col indices
         local rip = randomizedIndices[randomPosition]
         local rowIndex = rip[1]
         local colIndex = rip[2]
         randomPosition = randomPosition + 1
         if randomPosition > #randomizedIndices then
            randomPosition = 1
         end
        
         elapsed('before _sampleGradient()')
         gradient = self:_sampleGradient(x, rowIndex, colIndex)
         elapsed('after _sampleGradient')
      else
         -- points is a sequence from which rowIndex and colIndex have been
         -- extracted
         gradient = self:_sampleGradient(x, rowIndex, colIndex)
      end

      gradient:resize(nElements)
      
      elapsed('before collect garbage')
      collectgarbage()
      elapsed('after collect garbarge')

      v('loss', loss)
      v('gradient size', gradient:size())

      if writeProgress then
         print('returnedOpfunc: loss', loss)
      end

      elapsed('just before return')
      return loss, gradient
   end -- returnedOpfunc

   if timing then
      print('Complete:makeOpfunc CPU seconds', tc:cumSeconds())
   end

   return returnedOpfunc
end -- makeOpfunc

      
function Completion:print()
   limitEntries = limitEntries or 0
   print('Completion rank=', self.rank)
   print('Completion im=') self.im:print()
   print('Completion weights=') print(self.weights)
end -- print

function Completion:printHead(limitEntries)
   limitEntries = limitEntries or 10
   self:print(limitEntries)
end -- printHead

function Completion:rmse(weights)
   -- return RMSE using current weights; do not use the regularizer

   local trace = false
   local me = 'Completion:rmse: '

   self:_checkWeights(weights, 'weights')

   local lossNoRegularizer = self:_nonRegularizedLoss(weights)
   local rmse = math.sqrt(lossNoRegularizer / self.im:getNElements())
   if trace then
      print(me .. 'lossNoRegularizer', lossNoRegularizer)
      print(me .. 'nElements', self.im:getNElements())
      print(me .. 'rmse', rmse)
   end
   return rmse
end -- rmse


function Completion.serialize(path, c)
   -- write Completion c to file
   -- NOTE: class method
   -- NOTE: write in binary mode, or otherwise writeObject truncates
   --       double fields to only a few decimal points, resulting in 
   --       loss of precision when deserializing

   -- type and value check
   -- NOTE: cannot use _check* methods without constructing an object
   assert(path, 'path not provided')
   assert(type(path) == 'string')
   assert(c, 'completion object not provided')
   assert(torch.typename(c) == 'Completion')

   local file = torch.DiskFile(path, 'w')
   assert(file, 'could not open file: ' .. path)
   file:binary()

   file:writeObject(c)

   file:close()
end -- serialize

function Completion:setWeights(weights)
   -- set self.weights to weights, after validation
   self:_check2DTensor(weights, 'weights')
   local rank = weights[1]:size(1)
   self:_checkPositiveInteger(rank, 'rank')
   
   self.rank = rank
   self.weights = weights
end -- setWeights

-----------------------------------------------------------------------------
-- private methods
-----------------------------------------------------------------------------

function Completion:_callOptim(x, state, points, checkState, optimFunction)
   -- call an optim function after constructing a suitable opfunc
   -- ARGS:
   -- x                 : 2d Tensor, initial weights
   -- state             : table, passed to optim.lbfgs without modification
   -- points            : string, which point to evaluate opFunc at
   --                     oneOf{all, random}
   -- checkState        : function to check state for errors
   -- optimFunction     : function that does the optimization (ex: optim.cg)
   -- RETURNS what optim.lbfgs returns:
   -- xStar             : value of x at end of 1 or more iterations
   -- tableLosses       : table of numbers
   --                     table[1] == loss before the weights were updated
   --                     table[#table] == loss on next to final evaluation
   --                     NOTE: tableLosses does not include loss(xStar)
   -- MUTATES
   -- state             : table, the optim function mutates this table
   --                     in addition, this function adds a field printedLines
   --                     which is the sequence of lines printed by the optim
   --                     function (state.verbose == true causes the optim
   --                     function to print)
   -- ref: https://github.com/koraykv/optim/blob/master/lbfgs.lua

   local v = makeVerbose(false, 'Completion:_callOptim')
   local debug = false -- why loss is different than another calc?
   local timing = false -- print CPU seconds used

   local tc
   if timing then
      tc = TimerCpu()
   end

   v('x size', x:size())
   v('state', state)
   v('points', points)
   v('checkState', checkState)
   v('optimFunction', optimFunction)
   v('self', self)

   assert(x, 'x not supplied')
   self:_checkWeights(x, 'x')

   assert(state, 'state not supplied')
   assert(type(state) == 'table')

   assert(points, 'points not supplied')
   assert(type(points) == 'string')

   assert(checkState, 'checkState not supplied')
   assert(type(checkState) == 'function')

   checkState(state) -- errors if there is a problem

   local opfunc = self:makeOpfunc(points)

   local originalWeightRows = self.weights:size(1)
   local originalWeightCols = self.weights:size(2)
   local nWeights = originalWeightRows * originalWeightCols

   -- save first two fields of any sequence printed by the optimFunction
   -- approach: temporarily redefine the global print function
   local redefinePrint = true
   local oldPrint = print
   local printedLines = {}
   if redefinePrint then
      function print(first, second, ...)
         -- print any line not generated by the optim function
         -- optim function lines begin with '<optim...'
         if type(first) == 'string' and
            string.sub(first, 1, 6) == '<optim' then
            printedLines[#printedLines + 1] = {first, second}
         end
         oldPrint(first, second, ...)
      end -- print
   end
   
   v('calling optimFunction')

   local xstar, tableLosses = optimFunction(opfunc, 
                                            x:resize(nWeights), 
                                            state)
   v('returned from optimFunction')
  
   -- restore print function and save any printed lines
   if redefinePrint then
      print = oldPrint
      -- make sure don't overwrite optim result
      assert(state.printedLines == nil or
             #state.printedLines == 0)
      state.printedLines = printedLines
   end

   self.weights:resize(originalWeightRows, originalWeightCols)


   v('xstar size', xstar:size()) 
   v('tableLosses', tableLosses)
   v('lines printed by optim function', state.printedLines)


   if debug then
      local loss = self:loss(xstar)
      v('self:loss(xstar)', loss)
   end

   if timing then
      print('Completion:_callOptim: CPU seconds', tc:cumSeconds())
   end

   return xstar, tableLosses
end -- _callOptim

function Completion:_check2DTensor(value, name)
   assert(value, name .. ' must be supplied')
   assert(string.match(torch.typename(value), 'torch%..*Tensor'),
          name .. ' must be a Tensor')
   assert(2 == value:dim(), name .. ' must be a 2D Tensor')
end

function Completion:_checkBoolean(value, name)
   assert(value ~= nil, name .. ' must be supplied')
   assert(type(value) == 'boolean',
          name .. ' must be a boolean')
end

function Completion:_checkCompletion(value, name)
   assert(value, name .. ' must be supplied')
   assert(torch.typename(value) == 'Completion',
          name .. ' not a Completion')
end

function Completion:_checkIncompleteMatrix(value, name)
   assert(value, name .. ' must be supplied')
   assert(torch.typename(value) == 'IncompleteMatrix',
          name .. ' not an IncompleteMatrix')
end

function Completion:_checkIndices(rowIndex, colIndex, testUpperBound)
   if testUpperBound == nil then testUpperBound = true end

   assert(rowIndex, 'rowIndex not nil')
   assert(math.floor(rowIndex) == rowIndex, 'rowIndex must be an integer')
   assert(rowIndex > 0, 'rowIndex must be positive')
   if testUpperBound then
      assert(rowIndex <= self.im:getNRows(), 
             'rowIndex exceeds number of rows')
   end

   assert(colIndex, 'colIndex not nill')
   assert(math.floor(colIndex) == colIndex, 'colIndex must be an integer')
   assert(colIndex > 0, 'colIndex must be positive')
   if testUpperBound then
      assert(colIndex <= self.im:getNColumns(), 
             'colIndex exceeds number of columns')
   end
end

function Completion:_checkNonNegative(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'number', name .. ' must be a number')
   assert(value >= 0, name .. ' must be non-negative')
end

function Completion:_checkNumber(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'number', name .. ' must be a number')
end

function Completion:_checkPositive(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'number', name .. ' must be a positive number')
   assert(value > 0, name .. ' must be positive number')
end

function Completion:_checkPositiveInteger(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'number', name .. ' must be a positive integer')
   assert(math.floor(value) == value, name .. 'must be a positive integer')
   assert(value > 0, name .. ' must be a positive integer')
end

function Completion:_checkRange(value, boundlow, boundhigh, name)
   assert(value, name .. ' must be supplied')
   assert(boundLow <= value and value <= boundHigh,
          name .. ' must be in [' .. boundLow .. ',' .. boundHigh)
end

function Completion:_checkString(value, name)
   assert(value, name .. ' must be supplied')
   assert(type(value) == 'string',
          name .. ' must be a Lua string')
end

function Completion:_checkWeights(value, name)
   assert(value, name .. ' must be supplied')
   assert(torch.typename(value) == 'torch.DoubleTensor',
          name .. ' must be a 2D Tensor')
   assert(value:nDimension() == 2, name .. ' must be a 2D Tensor')
   assert(self.weights:size(1) == value:size(1) and
          self.weights:size(2) == value:size(2),
          name .. ' must be same shape as self.weights')
end

function Completion:_generateRandomIndices()
-- return sequence of {rowIndex, colIndex} in random order
   local v, trace = makeVerbose(false, 'Completion:_generateRandomIndices')

   local indices = {}
   for rowIndex, colIndex, value in self.im:triples() do
      indices[#indices + 1] = {rowIndex, colIndex}
   end
   local result = shuffleSequence(indices)  -- randomly permutate
   if trace then 
      v('result', result)
      for i = 1, #result do
         v('result[i]', result)
      end
   end
   return result
end -- _generateRandomIndices

function Completion:_generateWeightsKnown(nRows, nCols, rank, initialWeight)
   -- return 2D tensor containing the specified weight
   -- ARGS:
   -- nRows         : integer > 0, number of rows in the Completion
   -- nCols         : integer > 0, number of columns in the Completion
   -- rank          : integer > 0, rank of the solution
   -- initialWeight : number, the value of every element in the 
   --                    generated weights
   -- RETURNS: 2D tensor of size (nRows + nCols) x rank 
   --             with every entry == weights

   -- type and value check ARGS
   self:_checkPositiveInteger(nRows, 'nRows')
   self:_checkPositiveInteger(nCols, 'nCols')
   self:_checkPositiveInteger(rank, 'rank')
   self:_checkNumber(initialWeight, 'initialWeight')

   local size1 = nRows + nCols

   local weights = torch.Tensor(size1, rank):fill(initialWeight)
   
   return weights
end -- _generateWeightsKnown

function Completion:_generateWeightsRandom(nRows, nCols, rank, averageValue)
   -- return 2D tensor containing random weights
   -- ARGS:
   -- nRows        : integer > 0, number of rows in the Completion
   -- nCols        : integer > 0, number of columns in the Completion
   -- rank         : integer > 0, rank of the solution
   -- averageValue : number, average known value in the Completion
   -- RETURNS: 2D tensor of size (nRows + nCols) x rank sampled from 
   -- N(sqrt(averageValue), 1)
   
   -- type and value check ARGS
   self:_checkPositiveInteger(nRows, 'nRows')
   self:_checkPositiveInteger(nCols, 'nCols')
   self:_checkPositiveInteger(rank, 'rank')
   self:_checkNumber(averageValue, 'averageValue')

   local size1 = nRows + nCols
   local averageWeight = math.sqrt(math.abs(averageValue / rank))

   local weights = torch.randn(size1, rank) + averageWeight
   
   return weights
end -- _generateWeightsRandom

function Completion:_gradient(x)
   -- return the gradient of the loss
   -- at all the sample points using the weights x
   -- ARGS
   -- x : Tensor of weights, can be 1D or 2D
   --     Note  that self.weights are not used except to size the gradient
   -- RETURNS
   -- gradient : Tensor
   
   local v = makeVerbose(false, 'Completion:_gradient')


   v('x size', x:size())

   assert(x)
   assert(torch.typename(x) == 'torch.DoubleTensor')
   assert(x:nDimension() == 2, 'x not 2D')
   assert(x:size(1) == self.weights:size(1), 'x shape not same as weights')
   assert(x:size(2) == self.weights:size(2), 'x shape not same as weights')

   -- create and fill gradient with regularizer values 2 * lambda * x
   local gradient = torch.mul(x, 2 * self.lambda)

   v('gradient before sample updates size', gradient:size())

   -- add in the gradient of the loss at all the known points
   local nRows = self.im:getNRows()
   for rowIndex, colIndex, actual in self.im:triples() do
      -- unwind the call to self_gradientLoss
      --local gl = self:_gradientLoss(x, rowIndex, colIndex)
      --gradient = gradient + gl

      local rowOffset = rowIndex
      local colOffset = nRows + colIndex
      local estimate = torch.dot(x[rowOffset], x[colOffset])
      
      local diff = actual - estimate
      gradient[rowOffset] = 
         gradient[rowOffset] + torch.mul(x[colOffset], - 2 * diff)
      gradient[colOffset] = 
         gradient[colOffset] + torch.mul(x[rowOffset], - 2 * diff)

      if trace then
         v('rowIndex, colIndex, actual', 
               rowIndex, colIndex, actual)
         v('updated gradient', gradient)
      end
      
   end

   v('gradient size after sample updates', gradient:size())

   return gradient
end -- _gradient

function Completion:_nonRegularizedLoss(weights)
   -- return the loss without including the regularizer at the weights
   -- ARGS
   -- weights : 2D Tensor
   -- RETURNS
   -- loss    : number

   local trace = false
   local me = 'Completion:_nonRegularizedLoss: '

   self:_checkWeights(weights, 'weights')

   local nRows = self.im:getNRows()
   local loss = 0
   for rowIndex, colIndex, actual in self.im:triples() do
      -- unwind the function call to speed up 
      -- local estimate = self:estimate(weights, rowIndex, colIndex)
      local estimate = torch.dot(weights[rowIndex],
                                 weights[nRows + colIndex])
      local diff = actual - estimate
      loss = loss + diff * diff
      if trace then
         print(me .. 'rowIndex, colIndex, actual, estimate',
               rowIndex, colIndex, actual, estimate)
      end
   end
   return loss
end -- _nonRegularizedLoss


function Completion:_printSortedTable(table)
   -- print k,v with keys in increasing order

   assert(table)
   local sortedKeys = sortedKeys(table)
   for i = 1, #sortedKeys do
      local key = sortedKeys[i]
      print(key, table[key])
   end
end -- _printSortedTable

function Completion:_rowColWeights(weights, rowIndex, colIndex)
   -- return rank-sized 1D tensors for the weights at the row and column indices
   -- PROBABLY NOT USED

   return weights[rowIndex], weights[self.nRows + colIndex]
end -- _rowColWeights

function Completion:_sampleGradient(x, rowIndex, colIndex)
   -- return the gradient at self.known[rowIndex][colIndex] using the weights x
   -- if the sample is not known, error
   -- ARGS:
   -- x       : Tensor of weights, can be 1D or 2D
   -- lambda  : number, coefficient of the regularizer
   -- rowIndex : index of the sample's row
   -- colIndex : index of the sample's column
   -- RETURNS
   -- gradient : 1D Tensor, gradient wrt weights at specified sample
   
   local v = makeVerbose(false, 'Completion:_sampleGradient')
   local debug = false 
   local timing = false

   local tc
   if timing then tc= TimerCpu() end

   v('x size', x:size())
   v('rowIndex', rowIndex)
   v('colIndex', colIndex)
   v('self', self)


   assert(x)
   assert(torch.typename(x) == 'torch.DoubleTensor')
   self:_checkIndices(rowIndex, colIndex)
   
   -- create and fill gradient with the regularizer values: 2 * lambda * x
   local gradient = torch.mul(x, 2 * self.lambda)
   if debug then
      print('CPU to set gradient to regularizer',
            tc:cumSeconds())
      tc:reset()
   end

   -- add in gradient on the sample point
   local nRows = self.im:getNRows()
   local rowOffset = rowIndex
   local colOffset = nRows + colIndex

   local actual = self.im:get(rowIndex, colIndex)
   local estimate = torch.dot(x[rowOffset], x[colOffset])
   
   local diff = actual - estimate

   gradient[rowOffset] = 
      gradient[rowOffset] + torch.mul(x[colOffset], - 2 * diff)
   gradient[colOffset] = 
      gradient[colOffset] + torch.mul(x[rowOffset], - 2 * diff)

   if timing then
      print('Complete:_sampleGradient CPU seconds', tc:cumSeconds())
   end

   v('sample gradient size', gradient:size())
   return gradient

end -- _sampleGradient








      
      