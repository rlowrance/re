
import 'torch'
require 'sys'

nsamples = 1e5
dims = 55

features = randn(nsamples, dims)

distances = {}

-- SOLUTION A
for idx = 1,(#features)[1] do
   sys.tic()
   sample = Tensor(features:storage(), (dims*(idx-1))+1, 
                   nsamples, 0,   -- 1st dim
                   dims, 1)       -- 2nd dim

   match = sample:clone()
   match:add(-1,features)   --  match - features
   match:cmul(match)        --  (match - features)^2
   match:sum(2):squeeze(2)  --  \sum (match - features)^2
   match:sqrt()             --  euclidean distance
   distances[idx] = match
   print('time for 1 match: ' .. sys.toc())
end

-- SOLUTION C
for idx = 1,(#features)[1] do
   sys.tic()
   local match = Tensor((#features)[1])
   for midx = 1,(#features)[1] do
      match[midx] = features[idx]:dist(features[midx])
   end
   distances[idx] = match
   print('time for 1 match: ' .. sys.toc())
end
