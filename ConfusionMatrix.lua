-- ConfusionMatrix.lua
-- Class

if false then
   -- API Overview
   cm = ConfusionMatrix()
   cm.add(actual, predicted)  -- args are positive integers
   er = cm.errorRate()        -- fraction for which actual == predicted
   cm.printTo(file, heading)    -- print to open file
end

require 'makeVp'
require 'validateAttributes'

-- construction
local ConfusionMatrix = torch.class('ConfusionMatrix')

function ConfusionMatrix:__init()
   local initialSize = 2
   self.table = torch.Tensor(initialSize, initialSize):zero()
   self.largestClassNumber = 0
   self.largestActual = 0
   self.largestPredicted = 0
end

-- add a new pair
function ConfusionMatrix:add(actual, predicted)
   local vp = makeVp(2, 'ConfusionMatrix:add')
   vp(1, 'self', self, 'actual', actual, 'predicted', predicted)
   validateAttributes(actual, 'number', 'integer', '>', 0)
   validateAttributes(predicted, 'number', 'integer', '>', 0)

   self.largestClassNumber = math.max(actual, predicted, self.largestClassNumber)
   vp(2, 'self.largestClassNumber', self.largestClassNumber)

   while self.largestClassNumber > self.table:size(1) do 
      self:_expandRows()
   end

   while self.largestClassNumber > self.table:size(2) do
      self:_expandColumns()
   end

   vp(2, 'self.table', self.table)
   self.table[actual][predicted] = self.table[actual][predicted] + 1
end

-- private: copyOldToNew
function ConfusionMatrix:_copyOldToNew(new)
   new:zero()
   for i = 1, self.table:size(1) do
      for j = 1, self.table:size(2) do
         new[i][j] = self.table[i][j]
      end
   end
end

-- private: expand number of columns
function ConfusionMatrix:_expandColumns()
   local new = torch.Tensor(self.table:size(1), self.table:size(2) * 2)
   self:_copyOldToNew(new)
   self.table = new
end

-- private: expand number of rows
function ConfusionMatrix:_expandRows()
   local new = torch.Tensor(self.table:size(1) * 2, self.table:size(2))
   self:_copyOldToNew(new)
   self.table = new
end

-- errorRate
function ConfusionMatrix:errorRate()
   local vp = makeVp(0, 'ConfusionMatrix:errorRate')
   local nObs = self.table:sum()
   assert(nObs > 0, 'no observations')

   local nCorrect = 0
   for i = 1, self.largestClassNumber do
      nCorrect = nCorrect + self.table[i][i]
   end

   vp(2, 'nObs', nObs, 'nCorrect', nCorrect)

   return (nObs - nCorrect) / nObs
end

-- printTo
function ConfusionMatrix:printTo(file, heading)
   -- assume counts fit into 7 digits
   local strFormat = '%7s'
   local numFormat = '%7d'
   
   local function strWrite(s)
      file:write(string.format(strFormat, s))
      file:write(' ')
   end

   local function numWrite(n)
      file:write(string.format(numFormat, n))
      file:write(' ')
   end

   local function nlWrite()
      file:write('\n')
   end

   file:write(heading .. '\n')
   
   strWrite(' ')
   strWrite('predictions')
   nlWrite()

   strWrite('actual')
   for i = 1, self.largestClassNumber do
      numWrite(i)
   end
   nlWrite()

   for i = 1, self.largestClassNumber do
      numWrite(i)  -- actual  
      for j = 1, self.largestClassNumber do
         numWrite(self.table[i][j]) -- prediction[j]
      end
      nlWrite()
   end
end
