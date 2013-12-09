-- kroneckerProduct.lua
-- ARGS
-- t1 : Tensor, for now, a 1D Tensor
-- t2 : Tensor, for now, 1 1D Tensor
-- RETURNS
-- product : KroneckerProduct of t1 and t2, for now, always a 1D Tensor
function _kroneckerProduct1(t1, t2)
   local vp = makeVp(0, '_kroneckerProduct1')
   assert(t1:nDimension() == 1)
   assert(t2:nDimension() == 1)
   local t1size = t1:size(1)
   local t2size = t2:size(1)
   local nElements = t1size * t2size
   local result = torch.Tensor(nElements)

   local indexResult = 0
   for index1 = 1, t1size do
      for index2 = 1, t2size do
         indexResult = indexResult + 1
         result[indexResult] = t1[index1] * t2[index2]
      end
   end
   return result
end

function _kroneckerProduct2(t1, t2)
   local vp = makeVp(0, '_kroneckerProduct2')
   assert(t1:nDimension() == 1)
   assert(t2:nDimension() == 1)
   local t1size = t1:size(1)
   local t2size = t2:size(1)
   local nElements = t1size * t2size
   local result = torch.Tensor(nElements)
   vp(2, 'initial result', result)
   
   for index1 = 1, t1size do
      local result_index = torch.Tensor(result:storage(), 
                                        t2size * (index1 - 1) + 1,
                                        t2size,
                                        1)
      vp(2, 'result_index', result_index)
      torch.mul(result_index, t2, t1[index1])
      vp(2, 'index1', index1, 'result', result)
   end
   return result
end

-- pick implementation
-- #2 takes about half the CPU time as number 1
function kroneckerProduct(t1, t2, implementation)
   assert(t1 ~= nil, 'missing argument t1')
   assert(t2 ~= nil, 'missing argument t2')
   implementation = implementation or 2
   if implementation == 1 then
      return _kroneckerProduct1(t1, t2)
   elseif implementation == 2 then
      return _kroneckerProduct2(t1, t2)
   else
      error('bad implementation value: ' .. tostring(implementation))
   end
end

