-- optim_vsgdfd.lua
-- ref: Tom Schaul and Yann LeCun
-- Adaptive learning rates and parallelization for stochastic, sparse, 
-- non-smooth gradients
-- ICLR 2013

-- The reference implementation (in Python) is at
-- https://github.com/schaul/py-optim/blob/master/PyOptim/algorithms/vsgd.py

require 'makeVp'
require 'optim'

-- Variance-based stochastic gradient descent with finite differences
--
-- ARGS:
-- gradients: function(w, batchId) gradients for a batch of samples.
--            This function is called twice for each batchId, once with w
--            and once with w + delta
--   ARGS:
--   w      : 1D Tensor
--   batchID: integer, starting at 1 and incremented each time a new
--            batch is to be used
--   RETURN:
--   f(w)        : avg loss at the samples in batch with id batchId
--   seq         : sequence of one or more gradients for the samples in the
--                 batch a weight w. The batch size need not be the same on 
--                 each call. The same number of gradients must be returned 
--                 for each value of batchid.
-- w        : 1D Tensor, the initial point of size d
-- state    : table describing state of optimizer; you can set these elements
--   state.c: optional number, default d / 10
--            scaling factor for initialization
--   state.verbose: optional non-negative integer, verbose level
--                  if 0, print only error messages
--                  if 1, also print args and returned values
--                  if 2, also print diagnostic information
--   state.epsilon : optional number > 0, default 1e-10
--                   A small number added to divisors so that division by zero
--                   never happens
--
-- RETURN:
-- wNew     : updated w value
-- {f(w)}   : value of f(w) before w was updated
-- 
-- SIDE EFFECT: update state. Of potential interest are these values
--   state.eta         : 1D Tensor, the step size in each direction. You can
--                       track this over the iterations.
--   state.tau         : 1D Tensor, the memory size. If this value gets large,
--                       L-BFGS might be faster.
--
-- NOTES:
-- 1. Consider stopping the iterations when there is no progress on the
--    validation set.
function optim.vsgdfd(gradients, w, state)
   -- 1: Check args and supply defaults
   assert(type(gradients) == 'function', 'gradients not a function')

   assert(type(w) == 'userdata', 'w not a torch.Tensor')
   assert(w:dim() == 1, 'w not 1 1D torch.Tensor')
   local d = w:size(1)

   assert(state ~= nil, 'state table not supplied (can supply {})')
   assert(type(state) == 'table', 'state is not a table')

   if state.c == nil then
      state.c = math.max(d / 10, 2)  -- per Tom Schaul
   end

   if state.verbose == nil then
      state.verbose = 0
   end

   if state.epsilon == nil then
      state.epsilon = 1e-10
      state.epsilonVector = torch.Tensor(d):fill(state.epsilon)
   end
   assert(state.epsilon > 0, 'epsilon not positive')

   if state.firstTime == nil then
      state.firstTime = true
   end

   -- setup verbose functions
   local vp = makeVp(state.verbose)

   -- print a sequence of Tensors, if at verbose level
   local function vpTensors(level, name, seq)
      if level >= state.verbose then
         for j = 1, #seq do
            vp(level, name .. '[' .. j .. ']=', seq[j])
         end
      end
   end

   if state.verbose >= 1 then
      vp(1, 'optim.vsgdfd gradients', gradients)
      vp(1, 'optim.vsgdfd w', w)
      vp(1, 'optim.vsgdfd state', state)
   end
   
   -- 2: Draw n samples, compute gradients (nablas) for each
   if state.batchId == nil then
      state.batchId = 1
   else
      state.batchId = state.batchId + 1
   end

   local fw, nablas = gradients(w, state.batchId)
   local n = #nablas  -- NOTE: batch size can vary on each iteration
   assert(n >= 1, 'gradients() returned no gradients')
   if state.verbose >= 2 then
      vp(2, 'd', d)
      vp(2, 'n', n)
   end
   vpTensors(2, 'nablas', nablas) 

   -- 3: Compute gradients on same samples with parameters shifted by delta=gAvg
   local function avg(seq, pow)  
      -- determine avg of seq of Tensors, each raised to power pow
      local sum = torch.Tensor(d):zero()
      local n  = #seq
      for _, tensor in ipairs(seq) do
         if pow == 1 then
            sum = sum + tensor
         elseif pow == 2 then
            sum = sum + torch.cmul(tensor, tensor)
         else
            error('bad pow = ' .. pow)
         end
      end
      local result = sum / #seq
      return result
   end -- function avg
   
   -- average gradient for the sample
   if state.firstTime then
      -- here on first call, estimate gAvg
      state.gAvg = avg(nablas, 1)
   end
   local delta = state.gAvg

   local _, nablaDeltas = gradients(w + delta, state.batchId)
   if state.verbose >= 2 then
      vp(2, 'delta', delta)
      vpTensors(2, 'nablaDeltas', nablaDeltas)
   end
   assert(#nablaDeltas == n,
          'second call to gradients() returned different number of gradients')

   -- 4: Compute finite-difference curvatures
   local hFds = {}
   for j = 1, n do
      hFds[j] = torch.abs(torch.cdiv(nablas[j] - nablaDeltas[j], 
                                     delta + state.epsilonVector))
   end
   vpTensors(2, 'curvatures hFds', hFds)

   -- 5: Initial averages and tau, if this is first time we are called.
   -- The initial values are the last terms in the text's update moving
   -- averages section of Algorithm 1.

   if state.firstTime then 
      -- here the first time
      -- state.gAvg has already been initialized
      -- scale the variance on the initial calculation only
      state.vAvg = avg(nablas, 2) * state.c -- scale the variance (not in text)
      state.hFdAvg = avg(hFds, 1)
      state.vFdAvg = avg(hFds, 2) 
      state.tau = torch.Tensor(d):fill(1)
      if state.verbose >= 2 then
         vp(2, 'first time values')
         vp(2, 'state.c', state.c)
         vp(2, 'state.vAvg', state.vAvg)
         vp(2, 'state.hFdAvg', state.hFdAvg)
         vp(2, 'state.vFdAvg', state.vFdAvg)
         vp(2, 'state.tau', state.tau)
      end
   end

   -- 6: Increase memory size if batch is an outlier
   -- Instead of comparing to square root values, compare to square of both
   -- sides. This is faster and avoids any problems if the quantity under the
   -- square root is negative numerically.
   local avgNabla = avg(nablas, 1)
   local avgHFd = avg(hFds, 1)
   vp(2, 'avgNabla', avgNabla)
   vp(2, 'avgHFd', avgHFd)

   local testLhs1 = avgNabla - state.gAvg  -- don't take abs() 
   local testLhs1Squared = torch.cmul(testLhs1, testLhs1)
   local rhsConstant = 4 / (n * n) -- square of 2/n
   local testRhs1Squared = 
      (state.vAvg - torch.cmul(state.gAvg, state.gAvg)) * rhsConstant
   local testLhs2 = avgHFd - state.hFdAvg  -- don't take abs()
   local testLhs2Squared = torch.cmul(testLhs2, testLhs2)
   local testRhs2Squared = 
      (state.vFdAvg - torch.cmul(state.hFdAvg, state.hFdAvg)) * rhsConstant
   if state.verbose >= 2 then
      vp(2, 'testLhs1Squared', testLhs1Squared)
      vp(2, 'testRhs1Squared', testRhs1Squared)
      vp(2, 'testLhs2Squared', testLhs2Squared)
      vp(2, 'testRhs2Squared', testRhs2Squared)
   end
   
   -- check each dimension
   for i = 1, d do 
      if testLhs1Squared[i] > testRhs1Squared[i] or
         testLhs2Squared[i] > testRhs2Squared[i]
      then
         -- increase memory size if outlier
         state.tau[i] = state.tau[i] + 1 
         vp(2, 'updated tau[' .. i .. ']', state.tau[i])
      end
   end
   vp(2, 'tau after updating for possible outliers', state.tau)

   -- 7: Update moving averages
   local one = torch.Tensor(d):fill(1)
   if not state.firstTime then
      local oneOverTau = torch.cdiv(one, state.tau)
      local oldWeight = one - oneOverTau
      local newWeight = oneOverTau 
      
      local function weightedAverage(old, new, pow)
         -- only scale vAvg on the very first estimate
         return 
            torch.cmul(oldWeight, old) + torch.cmul(newWeight, avg(new, pow))
      end
      
      state.gAvg = weightedAverage(state.gAvg, nablas, 1)
      state.vAvg = weightedAverage(state.vAvg, nablas, 2)
      state.hFdAvg = weightedAverage(state.hFdAvg, hFds, 1)
      state.vFdAvg = weightedAverage(state.vFdAvg, hFds, 2)
      if state.verbose >= 2 then
         vp(2, 'updated gAvg', state.gAvg)
         vp(2, 'updated vAvg', state.vAvg)
         vp(2, 'updated hFdAvg', state.hFdAvg)
         vp(2, 'updated vFdAvg', state.vFdAvg)
      end
   end

   -- 8: Estimate learning rate
   local gAvgSquared = torch.cmul(state.gAvg, state.gAvg)
   local firstTerm = torch.cdiv(state.hFdAvg, 
                                state.vFdAvg + state.epsilonVector)
   local secondNumerator = gAvgSquared * n
   local secondDenominator = 
      state.vAvg + gAvgSquared * (n - 1)
   local secondTerm = torch.cdiv(secondNumerator,
                                 secondDenominator + state.epsilonVector)
   state.eta = torch.cmul(firstTerm, secondTerm)
   if state.verbose >= 2 then
      vp(2, 'firstTerm', firstTerm)
      vp(2, 'secondNumerator', secondNumerator)
      vp(2, 'secondDenominator', secondDenominator)
      vp(2, 'secondTerm', secondTerm)
      vp(2, 'state.eta', state.eta)
   end

   -- 9: Update memory size
   local fraction = torch.cdiv(gAvgSquared, state.vAvg + state.epsilonVector)
   state.tau = torch.cmul(one - fraction, state.tau) + one
   if state.verbose >= 2 then
      vp(2, 'fraction', fraction)
      vp(2, 'state.tau', state.tau)
   end
   -- NOTE: if tau becomes large, consider switching to L-BFGS

   -- 10: Update parameter w
   local newW = w - torch.cmul(state.eta, avg(nablas, 1))
   state.firstTime = false

   if state.verbose >=1 then
      vp(1, 'optim.vsgdfd newW', newW)
      vp(1, 'optim.vsgdfd fw', fw)
      vp(1, 'optim.vsgdfd ending state', state)
   end

   return newW, {fw}
end