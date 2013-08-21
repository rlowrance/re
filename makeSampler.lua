-- makeSampler.lua

require 'makeSampleIndexer'

-- return function that randomly samples from data
-- ARGS:
-- xs : 2D Tensor, each row is a sample, say an input
-- ys : 1D Tensor, each element is a sample, say a target
-- zs : optional 1D Tensor, each element is a sample, say an importance
-- RETURNS one function
-- sample() : function returning a randomly selected sample
--   x : 1D Tensor, a row from xs
--   y : number, corresponding element of ys
--   z : optional number, corresponding element of zs, returned iff zs supplied
function makeSampler(xs, ys, zs)
   -- validate args
   assert(type(xs) == 'userdata', 'xs is not a Tensor')
   assert(xs:dim() == 2, 'xs is not a 2D Tensor')
   local n = xs:size(1)

   assert(type(ys) == 'userdata', 'ys is not a Tensor')
   assert(ys:dim() == 1, 'ys is not a 1D Tensor')
   assert(ys:size(1) == n, 'number of ys not same as number of xs')

   if zs ~= nil then
      assert(type(zs) == 'userdata', 'zs is not a Tensor')
      assert(zs:dim() == 1, 'zs is not a 1D Tensor')
      assert(zs:size(1) == n, 'number of zs is not same as number of xs')
   end

   -- clone args so that caller may change them
   local xsClone = xs:clone()
   local ysClone = ys:clone()
   local zsClone = nil
   if zs ~= nil then
      zsClone = zs:clone()
   end

   local sampleIndex = makeSampleIndexer(n)
      
   -- return randomly selected x, y, and z
   local function sample()
      local nextIndex = sampleIndex()
      if zxClone == nil then
         return xsClone[nextIndex], ysClone[nextIndex]
      else
         return xsClone[nextIndex], ysClone[nextIndex], zsClone[nextIndex]
      end
   end

   return sample
end