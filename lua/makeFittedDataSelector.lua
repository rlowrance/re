-- makeFittedDataSelector.lua

require 'makeVerbose'
require 'verify'


function makeFittedDataSelector(fold, kappa)
   -- return tensor such that table[i] == 1 iff obs i is not in the fold
   -- ARGS
   -- fold : integer > 0, fold number
   -- kappa : sequence, kappa[i] = fold number of observations i
   -- RETURNS
   -- tensor : 1D Tensor

   local v, verbose = makeVerbose(false, 'makeFittedDataSelector')
   verify(v,
          verbose,
          {{fold, 'fold', 'isIntegerPositive'},
           {kappa, 'kappa', 'isSequence'}})

   
   local result = torch.Tensor(#kappa):fill(1)  -- initially all selected

   for i = 1, #kappa do
      if kappa[i] == fold then
         result[i] = 0
      end
   end

   v('result', result)
   return result
end -- makeFittedDataSelector