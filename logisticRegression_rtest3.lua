-- logisticRegression_rtest3.lua
-- directly model 2 classes
-- score(Beta, X) = exp(Beta . X)
-- Prob(Y=j | Beta, X) = score(Beta_j,X) / (1 + sum_j score(Beta_j, X)),  
-- for j = 1, 2, ... J-1
-- Prob(Y=J | Beta, X) = 1 / (1 + sum_j score(Beta_j, X))

require 'makeVp'

torch.manualSeed(123)

local verbose = 2
local vp = makeVp(verbose)

local J = 2  -- number of classes
local betas = torch.rand(1, 2)
vp(0, 'Betas', betas)


local p = 10  -- number of samples
local inputs = torch.rand(p, 1)  
vp(0, 'inputs', inputs)

local function score(j, input)
   local vp = makeVp(0)
   vp(1, 'score j', j)
   vp(1, 'score input', input)
   assert(0 < j and j < J)
   local beta = betas[j]
   return beta[1] + beta[2] * input[1]
end

-- RETURN
-- Prob(Y=1)
-- Prob(Y=2)
local function probs(input)
   local sum = 0
   for j = 1, J - 1 do
      sum = sum + score(j, input)
   end
   local prob1 = score(1, input) / (1 + sum)
   local prob2 = 1 / (1 + sum)
   return prob1, prob2
end

for i = 1, p do
   local input = inputs[i]
   local pr1, pr2 = probs(input)
   print(string.format('%2d: x %f p1 %f p2 %f',
                       i, input[1], pr1, pr2))
end
   
