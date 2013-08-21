-- linregression.lua
-- linear regression

-- data from Schuam's, Statistics and Econometrics, 2nd edition, p. 157

--  {corn, fertilizer, insecticide}
data = {{40,  6,  4},
	{44, 10,  4},
	{46, 12,  5},
	{48, 14,  7},
	{52, 16,  9},
	{58, 18, 12},
	{60, 22, 14},
	{68, 24, 20},
	{74, 26, 21},
	{80, 32, 24}}

dataset = {}
function dataset:size() return #data end
for i = 1, dataset:size() do
   local input = torch.Tensor(2)
   local output = torch.Tensor(1)
   input[1] = data[i][2]; input[2] = data[i][3]
   output[1] = data[i][1]
   dataset[i] = {input, output}
end

-- build a linear model
require 'nn'
m = nn.Sequential()
ninputs = 2; noutputs = 2 
m:add(nn.Linear(ninputs, noutputs))

-- training
criterion = nn.MSECriterion()
trainer = nn.StochasticGradient(m, criterion)
trainer.learningRate = 1e-3
trainer:train(dataset)  -- the error increases to infinity

-- test versus book answers
-- book's model is corn = 31.98 + 0.65 * fertilizer + 1.11 * insecticides
book = {40.32, 42.92, 45.33, 48.85, 52.37, 57, 61.82, 69.78, 72.19, 79.42}
for i = 1,dataset:size() do
   local myPrediction = m.forward(dataset[i][1])
   print(string.format("%2d %6.2f %6.2f", i, myPrediction, book[i]))
end