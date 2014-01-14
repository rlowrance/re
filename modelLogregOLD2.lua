-- modelLogreg.lua
-- weighted logistic regression with 2 or more classes

-- API overview
-- Not a class, so as to make porting to MATLAB or Octave easier
-- Also, have the config table available on every function invocation provides
-- more flexibility. For example, functions may be selective traced by setting
-- config.verbose appropriately.
if false then
   -- public functions
   -- all Tensors are 2D Tensors
   model = modelLogreg
   config = {nClasses=3, nDimension=123, verbose=2, checkArgs=false}
   theta =  model.initialTheta(config)
   cost, gradient = model.costGradient(config, theta, X, y, w, lambda)
   predictions, probs = model.predict(config, theta, X)
   thetaStar = model.fit(config, X, y, w, lambda)

   -- private functions
   cost = model.cost(config, theta, X, y, w, lambda,
                     optionalProbs, optionalWeights)
   gradient = 
      model.gradient(config, theta, X, y, w, lambda,
                     optionalProbs, optionalWeights)
   fdGradient = 
      model.fdGradient(config, epsilon, theta, X, y, w, lambda)
   biases, weights = model.structureTheta(config, theta)
end

-- Some ideas for future versions to
--   . increase conformance to DYI
--   . speed up code by avoiding type checking and debug printing 
--     in production code
--   . avoids classes, which Octave does not support
--   . could be implemented within optim changing the number of args to its
--     functions
-- Have a config variable with at least these fields
--   nClasses      : integer >= 2, number of classes  DONE
--   nDimensions   : integer, number of columns in X  DONE
--   regularizer   : string in {'', 'L2', ...}       
--   verbose       : integer in {0, 1, 2, ...}        DONE
--   checkArgs     : boolean                          DONE
-- Then a function begins with
if false then
   function f(arg1, arg2, config)
      -- cache configuration variables
      local nClasses, nDimensions, verbose, checkArgs = 
         config.nClasses, config.nDimensions, config.verbose, config.checkArgs
      local v = true -- or false
      local checkArgs = true -- or false

      local vp = nil
      if v then vp = makeVp(2, 'function name') end
      if checkArgs then checkArg1(arg1) end
      -- other code
   end
end
-- Additionally, the module could declare other function to check the args
if false then
   local function checkX(X, config)
      assert(X:dim() == 2)
      assert(X:size(2) == config.nDimensions)
   end
   local function checkXYWLambda(X, y, w, lambda, config)
      checkX(X, config)
      checkY(y, config)
      checkw(y, config)
      checkLambda(lambda, config)
   end
end
      


-- REF: Kevin Murphy, p. 252 and following

require 'assertEq'
require 'ifelse'
require 'isnan'
require 'makeVp'
require 'maxIndex'
require 'optim'
require 'softmaxes'

modelLogreg = {}

--------------------------------------------------------------------------------
-- LOCAL FUNCIONS: check*()  argument checking
--------------------------------------------------------------------------------

local function checkX(config, X)
   assert(X ~= nil, 'X is nil')
   assert(X:dim() == 2 and
          X:size(1) > 0 and
          X:size(2) == config.nDimensions)
end

local function checkY(config, y, nObservations)
   assert(y ~= nil, 'y is nil')
   assert(y:dim() == 2 and
          y:size(1) == nObservations and
          y:size(2) == 1)
end

local function checkW(config, w, nObservations)
   assert(w ~= nil, 'w is nil')
   assert(w:dim() == 2 and
          w:size(1) == nObservations and
          w:size(2) == 1)
end

local function checkNclasses(config, nClasses)
   assert(nClasses ~= nil, 'nClasses is nil')
   assert(type(nClasses) == 'number' and 
          nClasses == config.nClasses)
end

local function checkNdimensions(config, nDimensions)
   assert(nDimensions ~= nil, 'nDimensions is nil')
   assert(type(nDimensions) == 'number' and 
          nDimensions == config.nDimensions)
end

local function checkTheta(config, theta)
   assert(theta ~= nil, 'theta is nil')
   assert(theta:dim() == 2 and
          theta:size(1) == (config.nClasses - 1) * (config.nDimensions + 1) and
          theta:size(2) == 1)
end

local function checkEpsilon(config, epsilon)
   assert(epsilon ~= nil, 'epsilon is nil')
   assert(type(epsilon) == 'number' and
          epsilon > 0)
end

local function checkProbs(config, probs, nObservations)
   assert(probs ~= nil, 'probs is nil')
   assert(probs:dim() == 2 and 
          probs:size(1) == nObservations and 
          probs:size(2) == config.nClasses)
end

local function checkWeights(config, weights)
   assert(weights ~= nil, 'weights is nil')
   assert(weights:dim() == 2 and 
          weights:size(1) == config.nClasses and 
          weights:size(2) == config.nDimensions)
end

local function checkLambda(config, lambda)
   assert(lambda ~= nil, 'lambda is nil')
   assert(type(lambda) == 'number' and
          lambda >= 0)
end

local function checkXYWLambda(config, X, y, w, lambda)
   checkX(config, X)
   local m = X:size(1)
   checkY(config, y, m)
   checkW(config, w, m)
   checkLambda(config, lambda)
   assert(type(lambda) == 'number' and lambda >= 0)
end

local function checkThetaXYWLambda(config, theta, X, y, w, lambda)
   checkTheta(config, theta)
   checkXYWLambda(config, X, y, w, lambda)
end

local function checkEpsilonThetaXYWLambda(config,
                                          epsilon,
                                          theta, X, y, w, lambda)
   checkEpsilon(config, epsilon)
   checkThetaXYWLambda(config, theta, X, y, w, lambda)
end


local function checkNdimensionsTheta(config, nDimensions, theta)
   checkNdimensions(config, nDimensions)
   checkTheta(config, theta)
end

local function checkThetaX(config, theta, X)
   checkTheta(config, theta)
   checkX(config, X)
end

--------------------------------------------------------------------------------
-- PRIVATE: cost()
--------------------------------------------------------------------------------

-- regularized cost
-- ARGS
-- config   : table of configuration parameters
-- theta    : column vector of parameters
-- X        : m x n Tensor of inputs
-- y        : m x 1 Tensor of class numbers in {1, 2, ..., nClasses}
-- w        : m X 1 Tensor of weights each >= 0
-- lambda   : number, coefficient of L2 regularizer
-- probs    : nil, or m x nClasses Tensor or probabilities
-- weights  : nil or nClasses x nDimensins Tensor of weights from the theta
-- RETURN
-- cost     : number, negative log likelihood of X, y, w given theta
function modelLogreg.cost(config, theta, X, y, w, lambda, probs, weights)
   -- configure
   local nClasses = config.nClasses
   local nDimensions = config.nDimensions
   local v = config.verbose >= 0

   local checkArgs = config.checkArgs

   local vp = nil
   if v then 
      vp = makeVp(config.verbose, 'modelLogreg.cost') 
      vp(1, 
      'nClasses', nClasses, 'theta', theta, 
         'X', X, 'y', y, 'w', w, 'lambda', lambda,
         'probs', probs, 'weights', weights)
   end

   local debug = true
   if debug then
      vp = makeVp(2, 'modelLogreg.cost debug')
   end

   -- validate args and establish defaults
   if checkArgs then 
      checkThetaXYWLambda(config, theta, X, y, w, lambda)
   end

   local m = X:size(1)
   local n = X:size(2)

   if probs == nil then
      _, probs = modelLogreg.predict(config, theta, X)
      if v then vp(1, 'probs', probs) end
   end

   if weights == nil then
      _, weights = modelLogreg.structureTheta(config, theta)
      if v then vp(1, 'weights', weights) end
   end

   if checkArgs then
      checkProbs(config, probs, m)
      checkWeights(config, weights)
   end

   -- determine cost without regularizer
   -- ref: Kevin Murphy p.253 with the addition of the weights
   -- l(W) = log \prod_i \prod_c (mu_{ic} ^ y_{ic}) ^ w_i
   --      = \sum_i \sum_c log((mu_{ic} ^ y_{ic}) ^ w_i)
   --      = \sum_i \sum_c w_i y_{ic} log(mu_{ic})
   -- NOTE: DO NOT MULTIPLY BY THE WEIGHTS
   -- NOTE: y_{ic} is zero most of the time, so that the \sum_c does not
   --       need to be implemented
   -- REF: http://www.cs.cmu.edu/~kdeng/thesis/logistic.pdf, section 4.3

   local largeNegativeValue = -1e100
   local logLikelihood = 0
   for i = 1, m do
      if v then 
         vp(2, '\ni', i, 'probs[i]', probs[i], 'y', y[i][1], 'w', w[i][1]) 
      end
      -- no need to examine each c value, as they all are zero except when
      -- c == y[i]
      local prob = probs[i][y[i][1]]
      if prob == 0 then
         if debug then vp(0, 'prob is zero') end
         vp(2, 'prob is zero')
         vp(2, 'i', i, 'probs[i]', probs[i], 'y', y[i][1])
         logLikelihood = largeNegativeValue
         if debug then stop('prob is zero') end
         break
      end
      local term = w[i][1] * math.log(prob)
      if v then vp(2, 'w', w[i][1], 'prob', prob, 'term', term) end
      if term ~= term or term == -math.huge then
         -- term is NaN or -inf
         -- should not happen
         vp(0, 
            'w', w[i][i], 
            'y_ic', ifelse(y[i][1] == c, 1, 0),
            'prob', prob,
            'math.log(prob)', math.log(prob))
         assert(not isnan(term))
         assert(term ~= -math.huge)
      end
      logLikelihood = logLikelihood + term
   end
   assert(not isnan(logLikelihood))
   assert(logLikelhood ~= 0, 'log likelihood is zero')
   
   cost = - logLikelihood
   assert(cost ~= math.huge, 'unregularized cost is infinite')
   
   if v then vp(2, 'cost no regularizer', cost) end
   
   -- add in regularizer (sum of squared weights)
   -- do not include the biases
   cost = 
      cost + 
      lambda * torch.sum(torch.cmul(weights, weights))  -- don't add the biases
   if v then vp(1, 'cost regularized', cost) end
   assert(cost ~= math.huge, 'regularized cost is infinite')
   return cost
end
   
--------------------------------------------------------------------------------
-- PUBLIC: costGradient()
--------------------------------------------------------------------------------

-- cost and gradient and parameters, inputs, targets, weights
-- ARGS
-- config   : table of configuration parameters
-- nClasses : number >= 2, number of classes
-- theta    : p x 1 Tensor, parameters
-- X        : m x n Tensor, features (does not have the 1's in col one)
-- y        : m x 1 Tensor of class numbers in {1, 2, ..., nClasses}
-- w        : m X 1 Tensor of weights each >= 0
-- lambda   : scalar, coefficient for L2 regularizer
-- RETURNS
-- cost     : number
-- gradient : column vector
function modelLogreg.costGradient(config, theta, X, y, w, lambda)
   local v = config.verbose >= 0
   local checkArgs = config.checkArgs
   local tolerance = 1e-3
   if config.tolerance then tolerance = config.tolerance end
   local testGradient = false
   if config.testGradient == true then
      testGradient = true
      v = true
   end

   local vp = nil
   -- verbose level needs to be 0, in order to accomodate printing of
   -- comparison between gradient and fd gradient
   if v then vp = makeVp(0, 'modelLogreg.costGradient') end

   --local testGradient = true
   -- NOTE: testGradient with fail if any of the probabilities is zero
   -- In that case, the cost function returns a constant value
   if testGradient then
      vp(0, 'turn off test of gradient for production')
   end
   
   if v and false then
      vp(1, 'nClasses', nClasses, 'theta', theta, 'X size', X:size(),
         'y size', y:size(), 'w size', w:size(), 'lambda', lambda)
      vp(2, 'X', X, 'y', y, 'w', w)
   end

   -- validate args
   if checkArgs then
      checkThetaXYWLambda(config, theta, X, y, w, lambda)
   end

   local m = X:size(1)
   local n = X:size(2)

   local _, probs = modelLogreg.predict(config, theta, X)
   local biases, weights = modelLogreg.structureTheta(config, theta)
   
   local cost = 
      modelLogreg.cost(config, theta, X, y, w, lambda, probs, weights)
   local gradient = 
      modelLogreg.gradient(config, theta, X, y, w, lambda, probs, weights)

   if testGradient then
      local epsilon = 1e-10
      local fdGradient = 
         modelLogreg.fdGradient(config, epsilon, theta, X, y, w, lambda)
      if v then vp(0, 'check gradient vs. finite difference gradient') end
      assert(fdGradient:dim() == 2 and 
             fdGradient:size(1) == gradient:size(1) and
             fdGradient:size(2) == 1)
      --vp(2, 'gradient', gradient, 'fdGradient', fdGradient)
      for i = 1, fdGradient:size(1) do
         vp(0, string.format('i %d gradient %9.6f fdGradient %9.6f',
                             i, gradient[i][1], fdGradient[i][1]))
      end
      assertEq(gradient, fdGradient, tolerance)
   end

   if v then
      vp(1, 'cost', cost, 'gradient', gradient)
   end
   return cost, gradient
end

--------------------------------------------------------------------------------
-- PRIVATE: fdGradient()
--------------------------------------------------------------------------------
-- gradient determined using finite differences
-- ARGS
-- config     : table of configuration parameters
-- epsilon    : number, difference in each dimension
-- theta      : column vector of parameters
-- X          : m x n Tensor of observations
-- y          : m x 1 Tensor of target values
-- w          : m x 1 Tensor of importances
-- lambda     : number, coefficient of L2 regularizer
-- RETURNS
-- fdGradient : column vector
function modelLogreg.fdGradient(config, epsilon, theta, X, y, w, lambda) 
   -- configure
   local v = config.verbose >= 0
   local checkArgs = config.checkArgs

   local vp = nil
   if v then vp = makeVp(config.verbose, 'modelLogreg.fdGradient') end

   -- validate args
   if checkArgs then 
      checkEpsilonThetaXYWLambda(config, epsilon, theta, X, y, w, lambda)
   end

   local fdGradient = theta:clone():zero()
   if v then vp(2, 'epsilon', epsilon, 'theta', theta) end
   for d = 1, theta:size(1) do
      if v then vp(2, 'd', d) end
      local thetaPlus = theta:clone()
      thetaPlus[d] = thetaPlus[d] + epsilon

      local costPlus = 
         modelLogreg.cost(config, thetaPlus, X, y, w, lambda)
      if v then vp(2, 'thetaPlus', thetaPlus, 'costPlus', costPlus) end

      local thetaMinus = theta:clone()
      thetaMinus[d] = thetaMinus[d] - epsilon
      local costMinus = 
         modelLogreg.cost(config, thetaMinus, X, y, w, lambda)
      if v then vp(2, 'thetaMinus', thetaMinus, 'costMinus', costMinus) end

      -- NOTE: costPlus and costMinus can be the same if the weight is 0
      --assert(costPlus ~= costMinus)

      fdGradient[d][1] = (costPlus - costMinus) / (2 * epsilon)
      assert(not isnan(fdGradient[d][1]))
      if v then vp(2, 'd', d, 'fdGradient[d]', fdGradient[d]) end
   end
   vp(1, 'fdGradient', fdGradient)
   return fdGradient
end

-- fit model, returning optimal parameters
-- use L-BFGS and the full gradient
-- config   : table of configuration parameters
--            config.fitMethod = {optim, opfunc} control how the fit is done
-- X        : m x n Tensor of inputs
-- y        : m x 1 Tensor of class numbers in {1, 2, ..., nClasses}
-- w        : m X 1 Tensor of weights each >= 0
-- lambda   : number, coefficient of L2 regularizer
-- RETURNS
-- thetaStar : column vector of optimal parameters
function modelLogreg.fit(config, X, y, w, lambda)
   -- configure
   local v = config.verbose >= 0
   local vp = nil
   if v then 
      vp = makeVp(config.verbose, 'modelLogreg.fit') 
      vp(3, 'X', X, 'y', y, 'w', w, 'lambda', lambda)
   end

   local debug = true
   if debug then
      vp = makeVp(0, 'modelLogreg.fit')
      vp(0, 'turn off debug code')
   end
   
   if config.checkArg then
      checkXYWLambda(config, X, y, w, lambda)
   end

   -- set default fit method
   if config.fitMethod == nil then
      config.fitMethod = {'lbfgs', 'full'}
   end

   -- return cost and gradient at specified theta parameter and observations
   -- use all the observations (thus, implement the full gradient)
   -- ARGS:
   -- theta    : 1D or 2D Tensor
   -- RETURNS
   -- cost     : number
   -- gradient : 1D Tensor
   local nOpfuncCalls = 0
   local function opfuncFull(theta)
      local vp = nil
      if v then 
         vp = makeVp(config.verbose, 'modelLogreg.fit opfuncFull')
         --vp(1, 'theta', theta)
         vp(1, 'theta size', theta:size())
      end
      local vp = makeVp(2, 'modelLogreg.fit opfuncFull')
      nOpfuncCalls = nOpfuncCalls + 1

      -- view theta as 2D
      local theta2D = torch.Tensor(theta:storage(),
                                   1,                -- offset
                                   theta:size(1), 1, -- size 1, stride 1
                                   1, 0)             -- size 2, stride 2

      local cost, gradient = modelLogreg.costGradient(config,
                                                      theta2D,
                                                      X, y, w, lambda)
      if debug then
         vp(0, string.format('nOpfuncall %d cost %f',
                             nOpfuncCalls, cost))
      end

      -- view gradient as 1D
      gradient = torch.Tensor(gradient:storage(),   -- view as 1D
                              1,                    -- offset
                              gradient:size(1), 1)  -- size 1, stride 1
      --vp(1, 'cost', cost, 'gradient', gradient)
      return cost, gradient
   end

   local initialTheta = modelLogreg.initialTheta(config)
   
   local thetaStar = nil
   local fValue = nil

   -- select and use desired config.fitMethod
   if config.fitMethod[1] == 'lbfgs' then
      -- setup call to optim.lbfgs
      local state = {maxIter = 100, linesearch=optim.lswolfe}
      --if v then vp(0, 'fix maxIter') end
      
      if config.fitMethod[2] == 'full' then
         thetaStar, fValues = optim.lbfgs(opfuncFull, initialTheta, state)
      else
         vp(0, 'config.fitMethod', config.fitMethod)
         error('bad config.fitMethod opfunc')
      end

   else
      vp(0, 'config.fitMethod', config.fitMethod)
      error('bad config.fitMethod optimization')
   end
   if v then vp(2, 'fValues', fValues) end
   if v then vp(1, 'thetaStar', thetaStar) end
   if v then vp(1, 'nOpfuncCalls', nOpfuncCalls) end
   return thetaStar, fValues
end

   
   

--------------------------------------------------------------------------------
-- PRIVATE: gradient()
--------------------------------------------------------------------------------

-- regularized gradient and test using finite differences
-- ARGS
-- config   : table of configuration parameters
-- theta    : column vector of paramaters
-- X        : m x n Tensor of inputs
-- y        : m x 1 Tensor of class numbers in {1, 2, ..., nClasses}
-- w        : m X 1 Tensor of weights each >= 0
-- lambda   : number, coefficient of L2 regularizer
-- probs    : nil or m x nClasses Tensor of probabilities
-- weights  : nil or nClasses x nDimensions Tensor, theta without the biases
-- RETURNS
-- gradient : column vector
function modelLogreg.gradient(config, theta, X, y, w, lambda, probs, weights)
   -- configure
   local v = config.verbose >= 0
   local checkArgs = true
   local nClasses = config.nClasses

   local vp = nil
   if v then vp = makeVp(config.verbose, 'modelLogreg.gradient') end

   if v then   
      vp(1,  
         'nClasses', nClasses, 'theta', theta, 'X', X, 
         'y', y, 'w', w, 'lambda', lambda,
         'probs', probs, 'weights', weights)
   end

   -- validate args and set defaults
   if checkArgs then
      checkThetaXYWLambda(config, theta, X, y, w, lambda)
   end

   local m = X:size(1)
   local n = X:size(2)
   if v then vp(2, 'm', m, 'n', n) end

   if probs == nil then
      _, probs = modelLogreg.predict(config, theta, X)
   end

   if weights == nil then
      _, weights = modelLogreg.structureTheta(config, theta)
   end

   vp(1, 'probs', probs, 'weights', weights)

   if checkArgs then
      checkProbs(config, probs, m)
      checkWeights(config, weights)
   end

   -- ref: Kevin Murphy p.253 with the addition of the weights
   -- the weights scale the errors
   local gradient = torch.Tensor(nClasses - 1, n + 1):zero()
   for i = 1, m do
      for c = 1, nClasses - 1 do
         -- weighted error
         local werror = (probs[i][c] - ifelse(y[i][1] == c, 1, 0)) * w[i][1]
         if v then
            vp(2, 
               '\ni', i, 'c', c, 'prob', probs[i][c], 'y', y[i][1],
               'w', w[i][1], 'werror', werror)
         end
         local firstTerm = werror
         if v then
            vp(2, 'd', 1, 'term', werror)
         end
         gradient[c][1] = gradient[c][1] + werror
         for d = 2, n + 1 do
            local term = werror * X[i][d - 1]
            if v then
               vp(2, 'd', d, 'x', X[i][d-1], 'term', term)
            end
            gradient[c][d] = gradient[c][d] + term
         end
      end
   end
      
   if v then vp(2, 'gradient unregularized', gradient) end

   -- add in regularizer
   for c = 1, nClasses - 1 do
      -- don't update the bias
      for d = 2, n + 1 do
         --vp(2, 'c', c, 'd', d)
         --vp(2, gradient[c][d])
         --vp(2, weights[c][d-1])
         gradient[c][d] = gradient[c][d] + 2 * lambda * weights[c][d - 1]
      end
   end
      
   if v then vp(1, 'gradient regularized', gradient) end

   -- convert to column vector
   gradient = torch.Tensor(gradient:storage(),
                           1,
                           gradient:size(1) * gradient:size(2), 1,
                           1, 0)


   if v then vp(1, 'gradient structured as column vector', gradient) end
   return gradient
end

--------------------------------------------------------------------------------
-- PUBLIC: initialTheta()
--------------------------------------------------------------------------------

-- return suitable parameter vector theta
-- ARGS
-- nClasses : number, number of classes in the model
-- nDimensions : number, number of columns in X matrix (number of features)
-- RETURNS 
-- theta : n x 1 vector suitable initialized
function modelLogreg.initialTheta(config)
   local theta = torch.randn((config.nClasses - 1) *  
                             (config.nDimensions + 1))  -- N(0,1)
   return torch.Tensor(theta:storage(), -- convert to n x 1
                       1,                  -- offset
                       theta:size(1), 1,   -- size 1, stride 1
                       1, 0)               -- size 2, stride 2
end

   
--------------------------------------------------------------------------------
-- PUBLIC: predict()
--------------------------------------------------------------------------------

-- predict target and target distribution for logistic regression
-- ARGS:
-- config   : table of configuration parameters
-- theta    : p x 1 Tensor, parameters
-- X        : m x n Tensor of inputs
-- RETURNS
-- estimates : m X 1 Tensor of estimated target values
-- probs     : m x nClasses Tensor of probabilities
function modelLogreg.predict(config, theta, X)
   -- configure
   local v = config.verbose >= 0
   local checkArgs = config.checkArgs
   local nClasses = config.nClasses
   local debug = true
   if debug then 
      print('modelLogreg.predict DEBUG CODE ACTIVE')
   end

   local testVectorized = false

   local vp = nil
   if v then vp = makeVp(config.verbose, 'modelLogreg.predict') end
   if debug then vp = makeVp(2, 'modelLogreg.predict debug') end

   if testVectorized then
      print('TURN OFF testVectorized IN modelLogreg.predict')
   end

   if v then vp(1, 'config', config, 'theta', theta, 'X', X) end

   -- validate args
   if checkArgs then
      checkThetaX(config, theta, X)
   end

   local m = X:size(1)
   local n = X:size(2)

   local biases, weights = modelLogreg.structureTheta(config, theta)
   if v then vp(2, 'biases', biases, 'weights', weights) end

   -- results variables
   local estimates = torch.Tensor(m, 1)
   local probs = torch.Tensor(m, nClasses)

   -- prob(y = c | x^(i), Theta) propto exp(Theta_c^T x) = 
   -- exp(bias_c + x^(i) w_c) = exp(scores)
   for i = 1, m do
      if i % 1 == 0 then
         -- garbage collect if printing a lot
         vp(0, string.format('i %d memory used after gc %d',
                             i, memoryUsed()))
      end
      -- score for each class
      local scores1 = nil
      if testVectorized then
         local scores1 = torch.Tensor(nClasses)
         for c = 1, nClasses do
            scores1[c] = biases[c] + torch.dot(weights[c], X[i])
         end
         if v then vp(3, 'scores1', scores1) end
      end

      -- recompute w/ vectorization
      if v then
         vp(3, 'i', i, 
            'biases', biases, 'X[i,:]', X:narrow(1, i, 1), 'weights', weights)
      end
      local scores = torch.add(biases,
                               torch.mm(weights, X:narrow(1, i, 1):t()))
      if v then vp(3, 'scores', scores) end

      if testVectorize then
         if v then vp(2, 'scores1', scores1, 'scores', scores) end
         assertEq(scores1, scores)
      end

      local p = softmaxes(scores)
      if debug then
         for d = 1, p:size(1) do
            if p[d] == 0 then
               vp(0, 'found zero probability')
               vp(0, 'p', p)
               vp(0, 'i', i)
               vp(1, 'biases', biases)
               vp(1, 'X[i,:]', X:narrow(1, i, 1))
               vp(1, 'weights', weights)
               vp(1, 'scores', scores)
            end
         end
      end
              
      p[torch.eq(p,0)] = 1e-100    -- replace 0 values with a small value
      probs[i] = torch.div(p, torch.sum(p))  -- renormalize

      -- is there still a zero probability?
      if debug then
         for d = 1, scores:size(1) do
            if probs[i][d] == 0 then
               vp(2, 'i', i)
               vp(2, 'd', d)
               vp(2, 'probs[i]', probs[i])
               vp(2, 'found zero probability')
               stop()
            end
         end
      end

      if debug and i == 482512 then
         vp(2, 'biases', biases)
         vp(2, 'X[i,:]', X:narrow(1, i, 1))
         vp(2, 'weights', weights)
         vp(2, 'scores', scores)
         vp(2, 'probs[i]', probs[i])
      end
      if debug then
         for c = 1, probs[i]:size(1) do
            if isnan(probs[i][c]) then
               vp(3, 'scores', scores)
               vp(3, 'probs[i]', probs[i])
               vp(3, 'i', i, 'c', c)
               assert(not isnan(probs[i][c]))
            end
         end
      end
      estimates[i] = maxIndex(scores)
   end

   if v then vp(1, 'probs', probs, 'estimates', estimates) end
   return estimates, probs
end

--------------------------------------------------------------------------------
-- PRIVATE: structureTheta()
--------------------------------------------------------------------------------

-- return biases and weights
-- ARGS
-- config      : table
-- theta       : n x 1 Tensor
-- RETURNS
-- biases      : nClasses x 1 Tensor
-- weights     : nClasses X nDimensions Tensor
function modelLogreg.structureTheta(config, theta)
   local v = config.verbose > 0
   local checkArgs = config.checkArgs
   local nClasses = config.nClasses
   local nDimensions = config.nDimensions

   local vp = nil
   if v then
      vp = makeVp(config.verbose, 'modelLogreg.structureTheta')
      vp(1, 'nClasses', nClasses, 'nDimensions', nDimensions, 'theta', theta)
   end

   -- validate args
   if checkArgs then
      checkTheta(config, theta)
   end

   -- separate out biases and weights
   -- create all zeros biases and weights for last class
   local biases = torch.Tensor(nClasses, 1):zero()
   local weights = torch.Tensor(nClasses, nDimensions):zero()
   local index = 0
   for c = 1, nClasses - 1 do
      index = index + 1
      biases[c][1] = theta[index][1]   -- bias for class c
      for d = 1, nDimensions do     -- weights for class c
         index = index + 1
         weights[c][d] = theta[index][1]
      end
   end
   
   if v then vp(1, 'biases', biases, 'weights', weights) end
   return biases, weights
end
   
--[[
--------------------------------------------------------------------------------
-- PRIVATE: unstructureTheta()
--------------------------------------------------------------------------------

-- convert biases and weights into theta column vector
-- In the column vector form, the parameters for the last class are zero and
-- are not stored.
-- ARGS
-- biases      : nClasses x 1                    Tensor
-- weights     : nClasses x nDimensions          Tensor
-- RETURNS
-- theta       : (nClasses-1)(nDimensions+1) x 1 Tensor, a column vector
function modelLogreg.unstructureTheta(biases, weights)
   local vp = makeVp(2, 'modelLogreg.unstructureTheta')
   vp(1, 'biases', biases, 'weights', weights)

   -- validate args
   assert(biases:dim() == 2 and biases:size(2) == 1)
   local nClasses = biases:size(1)
   assert(weights:dim() == 2 and 
          weights:size(1) == nClasses)
   local nDimensions = weights:size(2)
   vp(2, 'nClasses', nClasses, 'nDimensions', nDimensions)

   -- make sure parameters for last class are zero
   assert(biases[nClasses][1] == 0)
   for d = 1, nDimensions do
      assert(weights[nClasses][d] == 0)
   end

   -- build consolidate parameter vector
   local theta = torch.Tensor((nClasses - 1) * (nDimensions + 1), 1)

   local index = 0
   for c = 1, nClasses - 1 do
      index = index + 1
      theta[index][1] = biases[c][1]
      for d = 1, nDimensions do
         index = index + 1
         theta[index][1] = weights[c][d]
      end
   end


   vp(1, 'theta', theta)
   return theta
end
   
   ]]
