-- logisticRegression_rtest4.lua
-- generate data and recover paryameters

require 'logisticRegression'
require 'makeVp'

local vp = makeVp(0)

torch.manualSeed(123)
--torch.manualSeed(3737)

n = 1000  -- number of observations
d = 2   -- number of dimensions in each observation
K = 3   -- number of classes
X = torch.rand(n, d)     -- covariates
Y = torch.Tensor(n)      -- targets
W = torch.rand(K, d)     -- beta's after first coordinate  
bias = torch.rand(K)     -- bias portion of beta's

vp(0, 'n', n)
vp(0, 'd', d)
vp(1, 'X', X)
vp(1, 'W', W)
vp(1, 'biases', biases)
vp(0, 'K', K)

-- softmax of x[index] (in [0,1])
function softmax(index, x)
   local vp = makeVp(0)
   vp(1, 'softmax index', index)
   vp(1, 'softmax x', x)
   local numerator = math.exp(x[index])
   local denominator = 0
   for i = 1, x:size(1) do
      denominator = denominator + math.exp(x[i])
   end
   vp(2, 'numerator', numerator)
   vp(2, 'denominator', denominator)
   local result =  numerator / denominator
   assert(result >= 0 and result <= 1)
   vp(1, 'softmax', result)
   return result
end

-- Pr(Y^i =c)
function makeProb(i, c)
   local vp = makeVp(0)
   vp(1, 'makeProb i', i)
   vp(1, 'makeProb c', c)
   local v = torch.Tensor(K)
   for k = 1, K do
      v[k] = bias[k] + torch.dot(X[i], W[k])
   end
   local p = softmax(c, v)
   vp(2, 'v', v)
   vp(1, 'makeProb', p)
   return p
end


-- generate probabilities
for i = 1, n do
   local sumProb = 0
   for c = 1, K do
      local probability = makeProb(i,c)
      vp(1, string.format('Pr(Y^%d = %d) = %f',
                          i, c, probability))
      sumProb = sumProb + probability
   end
   vp(1, string.format('sum Pr(Y^%d) = %f\n',
                       i, sumProb))
end

-- make targets
for i = 1, n do
   local prob1 = makeProb(i, 1)
   local prob2 = makeProb(i, 2)
   local prob3 = makeProb(i, 3)
   -- choose value of Y[i] at random using these probabilities
   local r = torch.uniform(0, 1)
   local y = 0
   if r <= prob1 then y = 1 
   elseif r <= prob1 + prob2 then y = 2
   else y = 3
   end
   Y[i] = y
   vp(1, string.format('%d %0.2f %0.2f %0.2f %0.2f %d',
                       i, prob1, prob2, prob3, r, y))
end

function count(Y, c)
   local n = 0
   for i = 1, Y:size(1) do
      if Y[i] == c then n = n + 1 end
   end
   return n
end

print('Y[i] == ' .. 1 .. ' ' .. count(Y, 1) .. ' times')
print('Y[i] == ' .. 2 .. ' ' .. count(Y, 2) .. ' times')
print('Y[i] == ' .. 3 .. ' ' .. count(Y, 3) .. ' times')


-- learn logistic regression model
epochs=100
learningRate = 0.0001
learningRateDecay = 0
optimParams={learningRate=learningRate,
             learningRateDecay=learningRateDecay}
model, predict = logisticRegression{inputs=X,
                                    targets=Y,
                                    epochs=epochs,
                                    lambda=0,
                                    optimFunction=optim.sgd,
                                    verbose=1,
                                    optimParams=optimParams}
vp(0, 'fitted model weights', model.weights)
vp(0, 'final loss', model.avgLoss[#model.avgLoss])

-- predict using training data
predictions = predict{inputs=X}

-- determine accuracy
nCorrect = 0
for i = 1, n do
   if Y[i] == predictions[i] then
      nCorrect = nCorrect + 1
   end
end
vp(0, 'accuracy', nCorrect / n)
vp(0, 'epochs', epochs)
vp(0, 'learningRate', learningRate)
vp(0, 'learningRateDecay', learningRateDecay)
print('ok logisticRegression_rtest4')
-- NOTE: the accuracy is about 1/3, which seems appropriate because
-- there are 3 cases and everything is generated randomly.