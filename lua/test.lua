-- test-dist.lua
-- Test Clement's fast disk approach in file efficient_nn.lua

import 'torch'

nsamples = 10
ndims = 3

query = randn(ndims)
features = randn(nsamples, ndims)
print('features\n', features)

queries = Tensor(query:storage(), 1, nsamples, 0, ndims, 1)
print('dist\n', dist)

-- Solution A: incorrect answer
do
   print('solution A')
   dist = queries:clone()    

   dist:add(-1,features)
   print('after add\n', dist)
   dist:cmul(dist)
   dist:sum(2):squeeze(2)  -- the sqeeze doesn't do what one hopes
   print('after sum\n', dist)
   dist:sqrt()
   print('after sqrt\n', dist)
end

-- Solution B: correct answer
do
   print('solution B')
   dist = queries:clone()

   --dist = add(dist, -1, features)
   dist:add(-1, features)
   print('after add')
   print('dist\n', dist)
   
   dist:cmul(dist)
   print('after cmul \n', dist)
   dist = sum(dist, 2):squeeze()                 -- dist is now 1D
   print('after sum \n', dist)
   dist:sqrt()
   print('after sqrt \n', dist)
   print('dist:size()', dist:size())
   dist2 = dist
end

-- Solution C: slow but correct
do
   print('solution C')
   dist = torch.Tensor(nsamples):zero()
   for obsIndex = 1, nsamples do
      dist[obsIndex] = torch.dist(query, features[obsIndex])
   end
   print('after sqrt \n', dist)
   print('dist:size()', dist:size())
   dist3 = dist
end

for i = 1, nsamples do
   print(i, dist2[i] - dist3[i])
end