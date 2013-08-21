-- modelLogreg01.lua
-- weighted logistic regression where y in {0, 1}

error('this module does not pass its unit tests')

-- REF: Andrew Ng, Coursera Machine Learning Course
-- programming exercise 2

require 'hasNaN'
require 'makeVp'
require 'optim'
require 'sigmoid'

modelLogreg01 = {}

-- API overview
if false then 
   m = modelLogreg01
   estimates, probs = m.predict(theta,X)
   cost, gradient = m.costGradient(theta, X, y, w, lambda)
   theta = m.initialTheta(nParameters)
   thetaStar, evals = m.fit(X, y, w, lambda)
end

require 'makeVp'

-- deconstruct theta into the bias and a vie of the remaining weights
-- ARGS:
-- theta   : (n + 1) x 1 Tensor
-- RETURNS
-- bias    : number, theta[1]
-- weights : n x 1 Tensor, theta[2:end], a view of the storage of theta
function modelLogreg01.deconstructTheta(theta)
   local bias = theta[1][1]
   local weights = torch.Tensor(theta:storage(), -- create theta[2:end]
                                2,                        -- offset
                                theta:size(1) - 1, 1,     -- size 1, stride 1
                                1, 0)                     -- size 2, stride 2
   return bias, weights
end

-- good value for initial theta (small not-all zero random numbers)
-- ARGS:
-- nParameters : number, number of elements in row of X (not counting the 1)
-- RETURNS
-- theta : (n + 1) x 1 Tensor (column vector)
function modelLogreg01.initialTheta(nParameters)
   assert(type(nParameters) == 'number' and nParameters >= 1)
   return torch.randn(nParameters + 1, 1) / nParameters
end

-- hypothesis function h_theta(x^i) = sigmoid(theta^T x^i)
-- ARGS
-- theta : (n + 1) x 1 Tensor of parameters
-- X     : m       x n Tensor of inputs
-- RETURNS
-- probs : m x 1     Tensor of probabilities
--                   probs[i][1] == probability that X[i,:] is 1
--                   to avoid taking log of 0, probs is constrained to 
--                   be in [0+eps, 1-eps]
function modelLogreg01.h(theta, X)
   local vp = makeVp(1, 'modelLogreg01.h')
   local DEBUG = TRUE
   vp(1, 'theta', theta, 'X', X)
   local epsilon = 1e-4

   -- validate args
   assert(X:dim() == 2)
   local m = X:size(1)
   local n = X:size(2)
   assert(theta:dim() == 2 and theta:size(1) == n + 1 and theta:size(2) == 1,
         'theta is not n+1 x 1')

   local bias, weights = modelLogreg01.deconstructTheta(theta)

   -- determine probs: h_theta(X) = sigmoid(theta^T X)
   local probs = sigmoid(torch.add(torch.mm(X, weights),
                                   bias))
   -- now probs in [0,1]

   -- avoid zero probabilities as they mess up other computations
   -- zero probability will result computationally if theta is large
   -- same problem happens if probability is 1 (as we take log(1-prob)
   local isZero = torch.eq(probs, 0):type('torch.DoubleTensor')
   local isOne = torch.eq(probs, 1):type('torch.DoubleTensor')
   probs = probs + torch.mul(isZero, epsilon)
   probs = probs - torch.mul(isOne, epsilon)
   if DEBUG then
      for i = 1, m do
         assert(probs[i] ~= 0)
         assert(probs[i] ~= 1)
      end
   end
   vp(1, 'probs after adjusting for 0 and 1', probs)
   return probs
end

-- prediction and probability of 1
-- ARGS
-- theta : n x 1 Tensor
-- X     : m x n Tensor
-- RETURNS
-- estimate : m x 1 Tensor, each element 0 or 1
-- prob     : m x 1 Tensor, 
--            each element probability that target == 1 given theta and X
--            constaint prob s.t. its never 0 or 1
function modelLogreg01.predict(theta, X)
   --[[ Octave code
   p = sigmoid(X * theta) >- threshold
   ]]
   local vp = makeVp(0, 'modelLogreg01.predict')
   vp(1, 'theta', theta, 'X', X)

   -- don't validate args, because h(theta, X) does that

   local probs = modelLogreg01.h(theta, X)

   -- predict 1 iff prob >= threshold
   local threshold = 0.5
   local estimates = torch.ge(probs, threshold):type('torch.DoubleTensor')
   vp(1, 'estimates', estimates, 'probs', probs)
   return estimates, probs
end

-- return regularized cost (PRIVATE FUNCTION)
function modelLogreg01.cost(probs, theta, y, w, lambda)
   -- don't validate arguments as caller as already done this
   -- unregularized cost J(theta) for weighted logistic regression
   -- J(theta) = (1/m) sum_{i=1}^m 
   -- [ -y^i w^i log(p(x^i)) - (1 - y^i) w^i log(1 - p(x^i)) ]
   local vp, verbose = makeVp(0, 'modelLogreg01.cost')
   local d = verbose > 0
   vp(1, 'probs', probs, 'w', w, 'lambda', lambda)
   if d then
      for j = 1, theta:size(1) do
         vp(1, string.format('theta[%d] = %.16f', j, theta[j][1]))
      end
   end

   local m = y:size(1)
   vp(2, 'y', y, 'w', w, 'probs', probs)
   local term1 = torch.cmul(torch.cmul(y, w),
                            torch.log(probs))
   vp(2,'term1', term1)

   local one = y:clone():fill(1)
   local term2 = torch.cmul(torch.cmul(one - y, w),
                            torch.log(one - probs))
   vp(2, 'term2', term2)

   -- unregularized cost
   local cost = - torch.sum(term1 + term2) / m
   assert(not isnan(cost))

   -- add the L2 regularizer
   local _, weights = modelLogreg01.deconstructTheta(theta)
   vp(2, 'weights', weights, 'm', m, 
      'sum weights^2', torch.sum(torch.cmul(weights,weights))) 
   local reg = (lambda / (2 * m)) * torch.sum(torch.cmul(weights, weights))
   vp(2, 'reg', reg)
   local costReg = cost + reg
   
   vp(1, 'cost', cost, 'costReg', costReg)
   assert(not isnan(costReg))
   return costReg
end

-- print components of unregularized gradient and finite-difference gradient
-- PRIVATE FUNCTION
-- ARGS:
-- gradient : (n + 1) x 1 Tensor, gradient computed by another method
-- theta    : (n + 1) x 1 Tensor, parameters
-- X        : m       x n Tensor, inputs
-- y        : m       x 1 Tensor, targets
-- w        : m       x 1 Tensor, weights
-- RETURNS nil
function modelLogreg01.compareGradients(gradient, theta, X, y, w)
   local vp = makeVp(2, 'modelLogreg01.compareGradients')
   local fdGradient = gradient:clone():zero()
   local eps = 1e-10
   
   local n = X:size(2)

   local function equal(a, b)
      assert(a:dim() == b:dim())
      assert(a:size(1) == b:size(1))
      assert(a:size(2) == b:size(2))
      assert(a:dim() == 2)
      for r = 1, a:size(1) do
         for c = 1, a:size(2) do
            if a[r][c] ~= b[r][c] then
               return false
            end
         end
      end
      return true
   end
   
   local function f(newTheta) 
      local vp = makeVp(2, 'f')
      local _, probs = modelLogreg01.predict(newTheta, X)
      local lambda = 0  -- don't regularize
      -- cannot call costGradient as that would create invite recursion
      local cost = modelLogreg01.cost(probs,
                                      newTheta,
                                      y,
                                      w,
                                      lambda)
      vp(1, 'newTheta', newTheta, 'probs', probs, 'cost', cost)
      return cost
   end
   
   vp(0, 'comparison of grad with fdGradient')
   local maxError = 0
   local epsSqrt = math.sqrt(eps)
   vp(2, 'epsSqrt', epsSqrt)
   for j = 1, n + 1 do
      local thetaMinus = theta:clone()
      thetaMinus[j] = thetaMinus[j] - eps
      assert(not equal(theta, thetaMinus, 0))
      local costMinus = f(thetaMinus)
      
      local thetaPlus = theta:clone()
      thetaPlus[j] = thetaPlus[j] + eps
      assert(not equal(thetaMinus, thetaPlus))
      local costPlus = f(thetaPlus)
      assert(costMinus ~= costPlus,
             'costMinus and costPlus are equal')
      
      fdGradient[j][1] = (costPlus - costMinus) / (2 * eps)
      vp(2, 'costPlus', costPlus, 'costMinus', costMinus)
      assert(not isnan(costPlus))
      assert(not isnan(costMinus))
      vp(0, string.format('j %d gradient %f fdGradient %f',
                          j, gradient[j][1], fdGradient[j][1]))
      local error = math.abs(gradient[j][1] - fdGradient[j][1])
      assert(error <= epsSqrt, 'error = ' .. tostring(error))
      if error > maxError then
         maxError = error 
      end
   end
   vp(0, 'max Error', maxError)
   assert(maxError <= epsSqrt)
end


-- return regularized gradient (PRIVATE FUNCTION)
-- ARGS:
-- theta    : (n + 1) x 1 Tensor of parameters
-- X        : m       x n Tensor of observations (each in a row)
-- y        : m       x 1 Tensor of targets
-- w        : m       x 1 Tensor of weights for observations
-- lambda   : number, coefficient of L2 regularizer
-- RETURNS
-- gradient : (n + 1) x 1 Tensor
function modelLogreg01.gradient(probs, theta, X, y, w, lambda)
   local vp = makeVp(2, 'modelLogreg01.gradient')
   local testGradient = true
   if testGradient then
      vp(0, 'TURN OFF TEST GRADIENT BEFORE PRODUCTION RUNS')
   end

   -- don't validate args, as caller has already done this

   local m = X:size(1)
   local n = X:size(2)

   local grad = theta:clone():zero()
   local errors = probs - y
   vp(2, 'errors', errors)
   local weightedErrors = torch.cmul(errors, w)
   vp(2, 'w', w, 'weightedErrors', weightedErrors, 'X', X)
   for j = 1, n + 1 do
      if j == 1 then
         grad[j] = torch.sum(weightedErrors) / m
      else
         vp(2, 'j', j, 'X:narrow', X:narrow(2, j - 1, 1))
         grad[j] = torch.sum(torch.cmul(weightedErrors, 
                                        X:narrow(2, j - 1, 1))) / m
      end
   end
   vp(2, 'grad', grad)

   -- maybe test gradient vs. finite difference version
   -- test unregularized gradient, not regularized gradient
   if testGradient then
      modelLogreg01.compareGradients(grad, theta, X, y, w)
   end

   -- regularize gradient
   for j = 2, n + 1 do
      grad[j] = grad[j] + (lambda / m) * theta[j][1]
   end
   vp(2, 'grad regularized', grad)
   
   return grad
end


-- return regulized cost (scalar) and gradient (column vector)
-- ARGS:
-- theta    : (n + 1) x 1 Tensor of parameters
-- X        : m       x n Tensor of observations (each in a row)
-- y        : m       x 1 Tensor of targets
-- w        : m       x 1 Tensor of weights for observations
-- lambda   : number, coefficient of L2 regularizer
-- RETURNS
-- cost     : number, average cost regularized
-- gradient : (n + 1) x 1 Tensor, regularized
function modelLogreg01.costGradient(theta, X, y, w, lambda)
   local vp = makeVp(3, 'modelLogreg01.costGradient')
   local testGradient = true  -- set to false for production code
   vp(1, 'theta', theta, 'X', X, 'y', y, 'w', w, 'lambda', lambda)
   --[[  octave code I submitted with no regularizer
   h = sigmoid(X * theta);
   J = (- sum(y .* log(h)) - sum((1 - y) .* log(1 - h))) / m;
   
   n = size(X)(2);  % number of columns in X and theta
   for j = 1:n
     grad(j) = sum((h - y) .* X(:,j)) / m;
   end
   ]]   

   -- don't validate theta, X because predict does this
   -- validate other parameters
   local m = X:size(1)
   local n = X:size(2)
   assert(y:dim() == 2 and y:size(1) == m and y:size(2) == 1,
         'y is not m x 1')
   assert(w:dim() == 2 and w:size(1) == m and w:size(2) == 1,
         'w is not m x 1')
   assert(type(lambda) == 'number' and lambda >= 0)


   local estimates, probs = modelLogreg01.predict(theta, X)
   vp(2, 'estimates', estimates, 'probs', probs)
   local costReg = modelLogreg01.cost(probs, theta, y, w, lambda)
   vp(2, 'costReg', costReg)
   
   local gradReg = modelLogreg01.gradient(probs, theta, X, y, w, lambda)
   return costReg, gradReg
end


  
-- return optimal theta to fit model to provided data using L-BFGS
-- ARGS:
-- X        : m       x n Tensor of observations (each in a row)
-- y        : m       x 1 Tensor of targets
-- w        : m       x 1 Tensor of weights for observations
-- lambda   : number, coefficient of L2 regularizer
-- RETURNS
-- thetaStar : (n + 1) x 1 Tensor, the optimal weights
-- evals     : table of function values
function modelLogreg01.fit(X, y, w, lambda)
   local vp = makeVp(2, 'modelLogreg01.fit')
   local DEBUGGING = false

   -- validate args
   assert(X:dim() == 2)
   local m = X:size(1)
   local n = X:size(2)
   assert(y:dim() == 2 and y:size(1) == m and y:size(2) == 1)
   assert(w:dim() == 2 and w:size(1) == m and w:size(2) == 1)
   assert(type(lambda) == 'number' and lambda >= 0)

   -- define opfunc needed by L-BFGS
   -- return f(theta) and df/dTheta
   local iteration = 0
   local function opfunc(theta)
      -- use full gradient (not stochastic gradient)
      
      local cost, gradient = modelLogreg01.costGradient(theta,
                                                        X,
                                                        y,
                                                        w,
                                                        lambda)
      local gradient1D = torch.Tensor(gradient:storage(),
                                      1,
                                      gradient:size(1), 1)
      iteration = iteration + 1
      vp(0, string.format('iteration %d cost %f',
                          iteration, cost))
      vp(1, 'opfunc theta', theta)
      vp(1, 'opfun gradient', gradient)
      vp(1, 'opfun gradient as 1D', gradient1D)
      return cost, gradient1D
   end

   -- configure L-BFGS
   state = {}
   --state.maxIter = 100
   
   -- call L-BFGS
   local lbfgs = optim.lbfgs
   if DEBUGGING then
      require 'testlbfgs'
      lbfgs = testlbfgs
   end
      
   local initialTheta = modelLogreg01.initialTheta(n)
  
   local thetaStar, evals = lbfgs(opfunc,
                                  initialTheta,
                                  state)

   vp(1, 'thetaStar', thetaStar)
   vp(2, 'evals', evals)
   return thetaStar, evals
end
