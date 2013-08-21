-- permuteTensor.lua

function permuteTensor(t, permutation)
   -- return new tensor with elements of t in permutated order
   local v, isVerbose = makeVerbose(true, 'permuteTensor')
   verify(v, isVerbose,
          {{t, 't', 'isTensor'},
           {permutation, 'permutation', 'isTensor1D'}, 
          })
   local nElements = t:size(1)
   assert(nElements == permutation:size(1),
          't and permutation must have same number of rows')
   local result
   if t:nDimension() == 1 then
      result = torch.Tensor(nElements)
   elseif t:nDimension() == 2 then
      result = torch.Tensor(nElements, t:size(2))
   else
      error('t must be 1D or 2D; is ' .. t:type())
   end
   for i = 1, nElements do
      result[i] = t[permutation[i]]
   end
   v('result', result)
   return result
end  -- permuteTensor