-- logistic regression training

-- softmax of a vector
function softmax(x)
  local largest = torch.max(x)
  local e = torch.exp(x-largest)
  local z1 = 1/torch.sum(e)
  return e * z1
end

-- run logistic regression model on sample
function LogregFprop(x,theta)
  local s = torch.mv(theta,x)
  return softmax(s)
end

function LogregFpropBprop(x,y,theta,L3)
  local s = torch.mv(theta,x)
  local p = softmax(s)
  local objective = -log(p[y])
  local target = torch.Tensor(theta:size(1)):zero()
  target[y] = 1
  local gradient = torch.ger( (p[y] - target), x) - theta*L2
  return objective, gradient
end

function LogregTrainSGD(X,Y,theta,L2,n,eta)
  local nsamples = X:size(1)
  for i = 1, n do
    sample = i % nsamples
    local objective, gradient = LogregFpropBprop(X[sample],Y[sample],theta,L2)
    torch.add(theta,-eta,gradient)
    totalObjective = totalObjective + objective
  end
  return totalObjective/n, theta
end
