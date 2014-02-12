-- dropZeroSaliences.lua
-- drop samples for which the salience is zero
-- ARGS
-- X              : Tensor 2D
-- y              : Tensor 1D
-- s              : Tensor 1D, the saliences
-- implementation : optional number, default 2
--                  timing tests in dropZeroSaliences_test show 2 is slightly faster than 1
-- RETURNS
-- newX           : Tensor 2D
-- newY           : Tensor 1D
-- newS           : Tensor 1D

local function implementation1(X, y, s)
   local hasNonZeroSalience = torch.ne(s, 0)
   local nNonZeroSalience = torch.sum(hasNonZeroSalience) -- possibly 0

   local newX = torch.Tensor(nNonZeroSalience, X:size(2))
   local newY = torch.Tensor(nNonZeroSalience)
   local newS = torch.Tensor(nNonZeroSalience)

   local newIndex = 0
   for i = 1, s:size(1) do
      if hasNonZeroSalience[i] == 1 then
         newIndex = newIndex + 1
         newX[newIndex] = X[i]
         newY[newIndex] = y[i]
         newS[newIndex] = s[i]
      end
   end

   return newX, newY, newS
end

local function implementation2(X, y, s)
   local hasNonZeroSalience = torch.ne(s, 0)
   local nNonZeroSalience = torch.sum(hasNonZeroSalience) -- possibly 0

   local selectedIndices = torch.LongTensor(nNonZeroSalience)
   local nextIndex = 0
   for i = 1, s:size(1) do
      if hasNonZeroSalience[i] == 1 then
         nextIndex = nextIndex + 1
         selectedIndices[nextIndex] = i
      end
   end

   local newX = X:index(1, selectedIndices)
   local newY = y:index(1, selectedIndices)
   local newS = s:index(1, selectedIndices)

   return newX, newY, newS
end

function dropZeroSaliences(X, y, s, implementation)
   -- check that X, y, s have same number of rows
   local nRows = X:size(1)
   assert(y:size(1) == nRows)
   assert(s:size(1) == nRows)

   -- set default implementation 
   implementation = implementation or 1

   -- dispatch
   if implementation == 1 then
      return implementation1(X, y , s)
   elseif implementation == 2 then
      return implementation2(X, y, s)
   else
      error('bad implementation')
   end
end
