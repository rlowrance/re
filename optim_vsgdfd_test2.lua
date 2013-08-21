-- optim_vsgdfs_test2.lua
-- unit test

require 'makeVp'
require 'optim'
require 'optim_vsgdfd'

verbose = 0
vp = makeVp(verbose)

-- return 2 gradients
gradientCalled = 0
function gradients(w, batchId)
   vp(1, 'gradients w', w)
   vp(1, 'gradients batchId', batchId)
   assert(batchId == 1)
   gradientCalled = gradientCalled + 1
   local loss
   local result
   if gradientCalled == 1 then
      result = {torch.Tensor{1,2},
                torch.Tensor{3,4}}
      loss = 10
   else
      result = {torch.Tensor{10,20},
                torch.Tensor{30,40}}
      loss = 20
   end
   vp(1, 'gradients loss', loss)
   vp(1, 'gradients result[1]', result[1])
   vp(2, 'gradients result[2]', result[2])
   return loss, result
end -- function gradients

d = 2
initialW = torch.Tensor(d):fill(0)
state = {verbose=verbose}
finalW, lossSeq = optim.vsgdfd(gradients, initialW, state)
vp(1, 'finalW', finalW)
assert(#lossSeq == 1)
assert(lossSeq[1] == 10)

function near(t, s)
   local t2 = torch.Tensor{s}
   local tolerance = 1e-4
   local diff = t - t2
   local dist = math.sqrt(torch.sum(torch.cmul(diff, diff)))
   if dist >= tolerance then
      vp(0, 't', t)
   end
   return dist < tolerance
end

assert(near(state.gAvg, {2, 3}))
assert(near(state.vAvg, {10, 20}))
assert(near(state.hFdAvg, {9, 9}))
assert(near(state.vFdAvg, {101.25, 90}))
assert(near(state.eta, {0.0508, 0.0621}))
assert(near(state.tau, {1.6, 1.55}))
assert(near(finalW, {-0.1016, -0.1862}))

print('ok optim_vsgdf_test2')

   
   