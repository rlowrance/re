-- test mse-criterion.lua

require 'nn'

model = nn.Sequential()
model:add(nn.Linear(1,1))

criterion = nn.MSECriterion()

input = torch.Tensor(1):fill(0.4)
target = torch.Tensor(0.8)

estimate = model:forward(input)
loss = criterion:forward(estimate, target)

print('estimate', estimate)
print('loss', loss)