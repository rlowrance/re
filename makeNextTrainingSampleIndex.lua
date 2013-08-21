-- makeNextTrainingSampleIndex.lua

-- return function to present training sample indices in random order
-- ARGS
-- isTraining: 1D Tensor over {0, 1}, a training samples exists iff [i] == 1
--
-- RETURNS function that iterates over {1, 2, ..., nTrainingSamples}
function makeNextTrainingSampleIndex(isTraining)
   assert(isTraining:dim() == 1)
   local verbose = 0
   local vp = makeVp(verbose)
   vp(1, 'isTraining', isTraining)

   local nTrainingSamples = isTraining:sum()
   local sampleIndices = torch.Tensor(nTrainingSamples)
   local nextSampleIndex = 0
   for i = 1, isTraining:size(1) do
      if isTraining[i] == 1 then
         nextSampleIndex = nextSampleIndex + 1
         sampleIndices[nextSampleIndex] = i
      end
   end
   vp(2, 'sampleIndices', sampleIndices)
   
   -- randomly permute the sample indices
   local _, randomOrder = torch.sort(torch.rand(nTrainingSamples))
   vp(2, 'randomOrder', randomOrder)

   local lastSampleIndex = 0
   local function nextTrainingSampleIndex()
      lastSampleIndex = lastSampleIndex + 1
      if lastSampleIndex > nTrainingSamples then
         lastSampleIndex = 1
      end
      return sampleIndices[randomOrder[lastSampleIndex]]
   end
   return nextTrainingSampleIndex
end
