-- center.lua

-- deprecated
error('center.lua IS DEPRRECATED. USE standardize.lua INSTEAD')

require 'makeVp'
require 'view1DAs2D'

-- center elements of a 2D Tensor using given columns means and standard
-- deviations
-- NOTE: The function standardize can be used to determine the means and
-- standard deviations.
-- ARGS
-- tensor : 2D Tensor with c columns
-- means  : 1D Tensor of size c
-- stds   : 1D Tensor of size c
-- RETURNS
-- centeredTensor : 2D Tensor
function center(tensor, means, stds)
   -- configure
   local checkVectorization = true
   local vp = makeVp(1, 'center')
   vp(1, 'tensor', tensor, 'means', means, 'stds', stds)

   -- validate inputs
   assert(tensor:dim() == 2)
   assert(means:dim() == 1)
   assert(stds:dim() == 1)
   
   local nCols = tensor:size(2)
   assert(nCols == means:size(1))
   assert(nCols == stds:size(1))

   local nRows = tensor:size(1)
   local centeredTensor = torch.Tensor(nRows, nCols)

   -- implementation 1: loops
   local centered1 = nil
   if checkVectorization then
      centered1 = centeredTensor:clone()
      for row = 1, nRows do
         for col = 1, nCols do
            centered1[row][col] = (tensor[row][col] - means[col]) / stds[col]
         end
      end
      vp(2, 'centered1', centered1)
   end

   -- implementation 2: no loops
   local means2D = view1DAs2D(means, nRows, nCols)
   local stds2D = view1DAs2D(means, nRows, nCols)
   centeredTensor = torch.cdiv(tensor - means2D,
                               stds2D)
   vp(1, 'centeredTensor', centeredTensor)

   -- check that implementations agree
   if checkVectorization then
      assertEq(check, centeredTensor, 0)
      vp(0, 'turn of check vectorization')
   end

   return centeredTensor
end
   