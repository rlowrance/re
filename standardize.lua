-- standardize.lua
-- standardize sequence or 2D Tensor
-- ARG
-- obj : object to be standardized; either a sequence or a 2D Tensor
--       a sequence, each element is transformed to (x-mu)/sd
--       a 2D Tensor with nCol columns, each column is transformed to (x-mu)/sd
-- means : optional 2D Tensor of size 1 x nCol
-- stds  : optional 2D Tensor of size 1 x nCol
--  if means and stds are supplied, then obj must be a 2D Tensor
--  if means and stds are not supplied, they are computed and returned
--    for a sequence, they are scalars
--    for a 2D Tensor, they are 2D tensors of size 1 x nCol
-- RETURNS 3 values
-- standardizedObj : of same kind as arg obj
-- means           : a number or 1D Tensor
-- sds             : a number or 1D Tensor

require 'viewAdditionalRows'

-- standardize sequence of values by 
-- subtracting their mean and dividing by their sd
-- ARGS
-- seq: sequence of numbers
-- RETURNS:
-- standardized : seq of numbers; 
--                standardized[i] = (seq[i] - mean(seq)) / stddev(seq)
-- mean         : number, the mean of seq
-- stddev       : number, the standard deviation of the seq
local function standardizeSeq(seq, mean, std)
   local standardized = {}
   for _, value in ipairs(seq) do
      standardized[#standardized + 1] = (value - mean) / std
   end

   return standardized, mean, std
end

-- use supplied means and standard deviation to standardize each element of t
-- ARGS
-- t     : 1D Tensor
-- means : 2D Tensor of size 1 x nCols
-- stds  : 2D Tensor of size 1 x nCols
local function standardize1DTensor(t, means, stds)
   local vp = makeVp(0, 'standardize1DTensor')
   vp(1, 't', t, 'means', means, 'stds', stds)
   
   local result = torch.cdiv(t - means, stds)
   return result
end

   
-- use supplied means and standard deviations to standardize each column of t
-- ARGS
-- t     : 2D Tensor
-- means : 2D Tensor of size 1 x nCols
-- stds  : 2D Tensor of size 1 x nCols
local function standardize2DTensor(t, means, stds)
   local vp = makeVp(0, 'standardize2DTensor')
   vp(1, 't', t, 'means', means, 'stds', stds)

   local nRows = t:size(1)
   local nCols = t:size(2)
   
   local meansExpanded = viewAdditionalRows(means, nRows)
   local stdsExpanded = viewAdditionalRows(stds, nRows)
   vp(2, 'meanExpanded', meansExpanded, 'stdsExpanded', stdsExpanded)

   local standardized = torch.cdiv(t - meansExpanded, stdsExpanded)
   vp(1, 'standardized', standardized)
   return standardized, means, stds
end

-- return either
-- mean, std   : 2 scalars, if type(obj) == sequence; OR
-- means, stds : 2 1D Tensors, if type(obj) == 2D Tensor
local function getMeansStds(obj)
   if type(obj) == 'table' then
      -- assume its a sequence
      local sum = 0.0
      for _, value in ipairs(obj) do
         sum = sum + value
      end
      
      local mean = sum / #obj
      
      local sumSquaredDifferences = 0
      for _, value in ipairs(obj) do
         local diff = value - mean
         sumSquaredDifferences = sumSquaredDifferences + diff * diff
      end
      
      return  mean, math.sqrt(sumSquaredDifferences / #obj)
   elseif type(obj) == 'userdata' and obj:dim() == 2 then
      -- assume its a 2D Tensor
      return torch.mean(obj, 1), 
             torch.std(obj, 1, true) -- true ==> normalize by n
   else
      error('obj has bad type')
   end
end

function standardize(obj, means, stds)
   local vp = makeVp(0, 'standardize')
   vp(1, 'obj', obj, 'means', means, 'stds', stds)
   if means == nil then
      if stds == nil then
         local means, stds = getMeansStds(obj)
         return standardize(obj, means, stds)
      else
         error('cannot supply stds if means not supplied')
      end
   else
      -- used provided means and standard deviations to center the obj values
      assert(stds, 'must provide stdvs when providing means')
      if type(obj) == 'table' then
         return standardizeSeq(obj, means, stds)
      elseif type(obj) == 'userdata' then
         -- assume its a Tensor
         if obj:dim() == 1 then
            return standardize1DTensor(obj, means, stds)
         elseif obj:dim() == 2 then
            return standardize2DTensor(obj, means, stds)
         else
            error('unimplemented num of dimensions = ' .. obj:dim())
         end
      else
         error('unimplemented type for obj; type = ' .. type(obj))
      end      
   end
end
