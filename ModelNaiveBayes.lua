-- ModelNaiveBayes.lua
-- classification using Naive Bayes

if false then
   m = ModelNaiveBayes(X, y, nClasses)  -- 1 <= y[i] <= nClasses
   optimalTheta, fitInfo = m:fit(fittingOptions)  -- fittingOptions includes any regularizer
   predictions, predictionInfo = m:predict(newX, optimalTheta)
end

require 'argmax'
require 'isTensor'
require 'keyWithMinimumValue'
require 'Model'
require 'printTableValue'
require 'torch'
require 'vectorToString'

-------------------------------------------------------------------------------
-- CONSTRUCTION
-------------------------------------------------------------------------------

local ModelNaiveBayes, parent = torch.class('ModelNaiveBayes', 'Model')

-- ARGS
-- X        : 2D Tensor, each row a vector of features
-- y        : 1D Tensor of integers >= 1, class numbers
-- nClasses : number of classes (max value in y)
function ModelNaiveBayes:__init(X, y, nClasses, errorIfSupplied)
   assert(errorIfSupplied == nil, 'lambda is not supplied as part of call to method fit')

   parent.__init(self)

   assert(isTensor(X), 'X is not a torch.Tensor')
   assert(X:nDimension() == 2, 'X is not a 2D Tensor')
   self.nSamples = X:size(1)
   self.nFeatures = X:size(2)

   assert(isTensor(y), 'y is not a torch.Tensor')
   assert(y:nDimension() == 1, 'y is not a 1D Tensor')
   assert(y:size(1) == self.nSamples, 'y has incorrect size')
   assert(torch.min(y) >= 1, 'y range not in {1, 2, ..., nClasses}')

   assert(type(nClasses) == 'number', 'nClasses is not a number')
   assert(nClasses >= 2, 'number of classes is not at least 2')
   local maxY = torch.max(y)
   assert(maxY <= nClasses, 'largest y class number exceeds number of classes')

   self.X = X
   self.y = y
   self.nClasses = nClasses
end


-------------------------------------------------------------------------------
-- PUBLIC METHODS
-------------------------------------------------------------------------------

-- return optimalTheta and perhaps statistics and convergence info
-- ARGS
-- fittingOptions : table with these fields :
--                  .method              : string; must be 'gaussian'
--                                         assume each x value is drawn from a Guassian with mean
--                                         and standard deviation determined by the training sample
-- RETURNS
-- optimalTheta   : secret object to be passed to predict. Contains these fields
--                  .targetProbabilities : 1D Tensor
--                                         tP[c] = empirical probability of class c in y values
--                  ,means               : 2D Tensor
--                                         means[c, j] = mean of X[:, j] when y[i] = c
--                  .stds                : 2D Tensor
--                                         stds[c, j] = standard deviation of X[:, j] when y[i] = c
-- fitInfo        : table with no fields
function ModelNaiveBayes:runFit(fittingOptions)

   assert(fittingOptions ~= nil, 'missing fitting options table')
   assert(fittingOptions.method ~= nil, 'missing fittingOptions.method value')
   assert(fittingOptions.method == 'gaussian', '.method must be "gaussian"')

   self.method = fittingOptions.method
   return self:_fitGaussian()
end


-- return predictions and perhaps some other info
-- ARGS
-- newX  : 2D Tensor, each row is an observation
-- theta : secret object from :fit method
-- RETURNS
-- predictions : 2D Tensor of probabilities
-- predictInfo : table
--               .mostLikelyClasses : 1D Tensor of integers, the most likely class numbers
function ModelNaiveBayes:runPredict(newX, theta)
   local vp = makeVp(0, 'ModelNaiveBayes:runrunPredict')
   vp(1, 'newX', newX, 'theta', theta, 'self', self)

   assert(newX ~= nil, 'newX is nil')
   assert(newX:nDimension() == 2, 'newX is not a 2D Tensor')
   
   assert(theta ~= nil, 'theta is nil')
   assert(type(theta) == 'table', 'theta is not the secret value from method fit')
   
   assert(self.method == 'gaussian', 'cannot happen')
   return self:_predictGaussian(newX, theta)
end


-------------------------------------------------------------------------------
-- PRIVATE METHODS
-------------------------------------------------------------------------------

function ModelNaiveBayes:_predictGaussian(newX, theta)
   -- return unnormalized probability that observation x is in class c
   local function uProbability(x, c)

      -- probability density of drawing x from a Guassian with given mean and std
      local function gaussian(x, mean, std)
         local vp = makeVp(0, 'gaussian')
         vp(1, 'x', x, 'mean', mean, 'std', std)
         local variance = std * std
         local coefficient = 1 / math.sqrt(2 * math.pi * variance)
         local difference = x - mean
         local term = (- difference * difference) / (2 * variance)
         local pd = coefficient * math.exp(term)
         vp(1, 'pd', pd)
         return pd
      end

      local vp = makeVp(0, 'uProbability')
      vp(1, 'x', x, 'c', c)
      local up = theta.targetProbabilities[c]
      vp(2, 'target probability', up)
      for j = 1, x:size(1) do
         local prob = gaussian(x[j], theta.means[c][j], theta.stds[c][j])
         vp(2, string.format('j %d uProb %f', j, prob))
         up = up * prob
      end
      vp(2, 'up', up)
      return up
   end

   local vp = makeVp(0, '_predictGaussian')

   local nNewSamples = newX:size(1)
   local probs = torch.Tensor(nNewSamples, self.nClasses)
   local mostLikelyClasses = torch.Tensor(nNewSamples)
   for i = 1, nNewSamples do
      local uProbs = torch.Tensor(self.nClasses)
      for c = 1, self.nClasses do
         uProbs[c] = uProbability(newX[i], c)
      end
      vp(2, 'uProbs', uProbs)

      probs[i] = uProbs:div(torch.sum(uProbs))
      mostLikelyClasses[i] = argmax(uProbs)
   end

   return probs, {mostLikelyClasses = mostLikelyClasses}
end

function ModelNaiveBayes:_fitGaussian()

   -- return mean, std, err
   local function getMeanStd(X, y, c, j)

      -- return mean, err
      local function getMean(X, y, c, j)
         local sum = 0
         local nFound = 0
         for i = 1, self.nSamples do
            if self.y[i] == c then
               nFound = nFound + 1
               sum = sum + X[i][j]
            end
         end
         if nFound == 0 then 
            return nil, 'none found'
         else
            return sum / nFound, nil
         end
      end
      
      -- return std 
      -- NOTE: the Wikipedia article uses (n - 1) weighting and we
      -- use n weighting. Thus our stds are higher than in the 
      -- Wikipedia article. We do this in order to be able to
      -- handle the case where their is one training sample for
      -- a given target value.
      local function getStd(X, y, c, j, mean)
         local vp = makeVp(0, 'getStd')
         vp(1, 'c', c, 'j', j, 'mean', mean)
         local sumSquaredDifferences = 0
         local nFound = 0
         for i = 1, self.nSamples do
            if self.y[i] == c then
               nFound = nFound + 1
               local value = X[i][j]
               local difference = value - mean
               if c == 1 and j == 1 then
                  -- for female foot
                  vp(2, 'value', value, 'difference', difference)
               end
               sumSquaredDifferences = sumSquaredDifferences + (difference * difference)
            end
         end
         vp(1, 'sumSquaredDifferences', sumSquaredDifferences, 'nFound', nFound)
         if nFound == 0 then
            error('cannot happen')
         else
            return math.sqrt(sumSquaredDifferences / nFound)
         end
      end
      
      local vp = makeVp(0, 'getMeanStd')
      vp(1, 'c', c, 'j', j)

      local mean, err = getMean(X, y, c, j)
      vp(1, 'mean', mean, 'err', err)
      if err then
         return nil, nil, err
      end

      local std, err = getStd(X, y, c, j, mean)
      if err then
         return nil, nil, err
      end
      vp(1, 'std', std)
      return mean, std, nil
   end

   -- BODY starts here
   local vp = makeVp(0, '_fitGaussian')
   
   local targetProbabilities = torch.Tensor(self.nClasses)
   for c = 1, self.nClasses do
      local n = torch.sum(torch.eq(self.y, c))
      targetProbabilities[c] = n / self.nSamples
   end
   vp(1, 'targetProbabilities', targetProbabilities)

   local means = torch.Tensor(self.nClasses, self.nFeatures)
   local stds = torch.Tensor(self.nClasses, self.nFeatures)
   vp(1, 'self.nClasses', self.nClasses, 'self.nFeatures', self.nFeatures)
   for c = 1, self.nClasses do
      for j = 1, self.nFeatures do
         local mean, std, err = getMeanStd(self.X, self.y, c, j)
         vp(1, string.format('c %d j %d mean %f var %f err %s', c, j, mean, std * std, err))
         
         if err == 'none found' then
            error(string.format('class %d does not occur in the data', c))
         elseif err ~= nil then
            error(err)
         end
         means[c][j] = mean
         stds[c][j] = std
      end
   end
   
   vp(1, 'means', means, 'stds', stds)

   return {targetProbabilities = targetProbabilities, means = means, stds = stds}
end
