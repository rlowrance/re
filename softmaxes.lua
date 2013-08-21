-- softmaxes.lua

require 'assertEq'
require 'makeVp'

-- return vector of softmaxes, guarding against numeric overflow
-- ARGS
-- v : 1D Tensor or n X 1 Tensor
-- RETURNS
-- sm : Tensor of same shape as input such that 
--      sm[i] = exp(v[i]) / \sum_j exp(v[j])
function softmaxes(v)
   local vp = makeVp(0, 'softmaxes')
   vp(1, 'v', v)

   -- handle n x 1 input
   if v:dim() == 2 then
      assert(v:size(2) == 1)
      local view = torch.Tensor(v:storage(),  -- view as 1D
                                1,             --- offset
                                v:size(1), 1)  -- size 1, stride 1
      local result = softmaxes(view)
      local view = torch.Tensor(result:storage(),   -- view as 2D
                                1,                  -- offset
                                result:size(1), 1,  -- size 1, stride 1
                                1, 0)               -- size 2, stride 0
       return view
   end
   
   assert(type(v) == 'userdata' and
          v:dim() == 1,
          'v is not 1D Tensor')

   local size = v:size(1)
   local exps = torch.Tensor(size)
   for i = 1, size do
      exps[i] = math.exp(v[i])
      if exps[i] == math.huge then
         -- infinite result
         -- assume its the only infinite result
         local result = v:clone():zero()
         result[i] = 1
         vp(1, 'result after finding infinity', result)
         return result
      end
   end
   vp(2, 'exps', exps)

   local sum = torch.sum(exps)
   local result = exps / sum

   vp(1, 'result', result)
   return result
end