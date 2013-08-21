-- allKwavgFold.lua

require 'all'

local v = makeVerbose(true, 'main')
function allKwavgFold(xs, foldXs, foldYs, lambda)
   local v = makeVerbose(true, 'allKwavgFold')
   v('xs', xs)
   v('foldXs', foldXs)
   v('foldYs', foldYs)
   v('lambda', lambda)
   assert(xs:size(2) == foldXs:size(2))
   assert(foldXs:size(1) == foldYs:size(1))
   local x3d = torch.Tensor(xs:storage(),
                            1,
                            xs:size(2), 0, -- plane size and stride
                            xs:size(1), xs:size(2), -- row size and stride
                            xs:size(2), 1  -- col size and stride
                           )
   v('x3d', x3d)
   local fx3d = torch.Tensor(foldXs:storage(),
                             1,
                             xs:size(2), xs:size(2), -- plane size and stride
                             xs:size(1), 0, -- row size and stride
                             xs:size(2), 1  -- col size and stride
                            )
   v('fx3d', fx3d)
   local d = torch.add(x3d, -1, fx3d)
   d:cmul(d)
   s = torch.sum(d, 2):squeeze()
   v('d', d)
   v('s', s)
end


-- test
nObs = 10
nDims = 3
nFolds = 4
kappa = {1,2,3,4,1,2,3,4,1,2}

xs = torch.Tensor(nObs, nDims)
ys = torch.Tensor(nObs)
for i = 1, nObs do
   ys[i] = i * 100
   for d = 1, nDims do
      xs[i][d] = 10 * i + d
      xs[i][d] = 10 * i + d
   end
end

v('xs', xs)
v('ys', ys)

modelXs = {}
modelYs = {}
for fold = 1, nFolds do
   foldXs = {}
   foldYs = {}
   for i = 1, nObs do
      if kappa[i] == fold then
         foldXs[#foldXs + 1] = xs[i]
         foldYs[#foldYs + 1] = ys[i]
      end
   end
   v('foldXs', foldXs)
   v('foldYs', foldYs)
   mXs = torch.Tensor(#foldXs, nDims)
   mYs = torch.Tensor(#foldYs)
   for n = 1, #foldXs do
      mYs[n] = foldYs[n]
      for d = 1, nDims do
         mXs[n][d] = foldXs[n][d]
      end
   end
   modelXs[#modelXs + 1] = mXs
   modelYs[#modelYs + 1] = mYs
end

for fold = 1, nFolds do
   print('data for fold', fold)
   print('fold xs') print(modelXs[fold])
   print('fold ys') print(modelYs[fold])
end

-- test just fold 1 for now
lambda = 2
fold = 1
result = allKwavgFold(xs, modelXs[fold], modelYs[fold], lambda)
   

