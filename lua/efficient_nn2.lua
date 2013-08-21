
import 'torch'
require 'sys'

nsamples = 1e5
dims = 55

features = randn(nsamples, dims)

distances = Tensor(nsamples,nsamples)

matches = features:clone()

for idx = 1,(#features)[1] do
   sys.tic()
   local sample = features[{ {idx} }]:expandAs(features)
   matches[{}] = features
   matches:add(-1,sample)                  --  match - features
   matches:cmul(matches)                   --  (match - features)^2
   match = matches:sum(2):squeeze(2)       --  \sum (match - features)^2
   match:sqrt()                            --  euclidean distance
   distances[idx] = match
   print('time for 1 match: ' .. sys.toc())
end
