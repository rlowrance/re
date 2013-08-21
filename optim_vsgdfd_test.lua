-- optim_vsgdfd_test.lua
-- unit test

require 'makeVp'
require 'optim'
require 'optim_vsgdfd'

local vp = makeVp(2)

-- Example function from Heath, Scientific Computing, p.282
-- but with coefficients in Tensor w
-- f(x,w) = w1 * x1^2 + w2 * x2^2
-- RETURN
-- f(x,w)
-- df_dw(x,w)
function myFunction(x, w)
   local vp = makeVp(1)
   vp(1, 'myFunction x', x)
   vp(1, 'myFunction w', w)
   assert(x:dim() == 1)
   assert(x:size(1) == 2)
   assert(w:dim() == 1)
   assert(w:size(1) == 2)
   local x1 = x[1]
   local x2 = x[2]
   local w1 = w[1]
   local w2 = w[2]
   local fx = w1 * x1 * x1 + w2 * x2 * x2
   local dfdw = torch.Tensor(2)
   df_dw[1] =  x1 * x1
   df_dw[2] =  x2 * x2
   vp(1, 'myFunction fx', fx)
   vp(1, 'myFunction df_dw', df_dw)
   return fx, df_dw
end

-- test myFunction
local w = torch.Tensor{0.5, 2.5}
local fx, dfdx = myFunction(torch.Tensor{1, 0}, w)
assert(fx == 0.5)
assert(dfdx[1] == 1)
assert(dfdx[2] == 0)
local fx, dfdx = myFunction(torch.Tensor{0, 1}, w)
assert(fx == 2.5)
assert(dfdx[1] == 0)
assert(dfdx[2] == 1)

-- opfunc: return gradients at samples using w
local timesCalled = 0
local function gradients(w, batchId)
   local vp = makeVp(1)
   vp(1, 'gradients w', w)
   vp(1, 'gradients batchId', batchId)
   local index = 
   local deltas = torch.Tensor(w:size(1)):fill(delta)
   if timesCalled == 0  then
      timesCalled = timesCalled + 1 
      local sample = torch.Tensor{1, 0}
      local _, atW1 = myFunction(sample, w)
      local wPlusDelta = w + deltas
      local _, atWPlusDelta1 = myFunction(sample, wPlusDelta)
      local sample = torch.Tensor{0,1}
      local _, atW2 = myFunction(sample, w)
      local _, atWPlusDelta2 = myFunction(sample, wPlusDelta)
      local result1 = {atW1, atW2}
      local result2 = {atWPlusDelta1, atWPlusDelta2}
      vp(1, 'gradients result1', result1)
      vp(1, 'gradients result2', result2)
      return result1, result2 
   else
      error('called too many times')
   end
end

-- test vsgdfd
local w = torch.Tensor{0.5, 2.5}  -- coefficients in text p 282
local state = {verbose=2}
local newW, fw = optim.vsgdfd(gradients, w, state)
vp(1, 'newW', newW)
vp(1, 'fw', fw)
error('write the test case')



                       
   