-- program_parcels_sfr_geocoded_info.lua
-- main program to create file parcels-sfr-geocoded-info.csv
-- The only input file is parcels-sfr-geocoded.csv
--
-- The output file is a CSV file containing one row for each row in the input file.
-- These are the columns in the output file:
--   hasFEATURE      one for each column in the input file
--                   1 if the corresponding row and column has the feature
--                   0 otherwise
--   hasNotFEATURE   the complement of column hasFEATURE
--   isTrain
--   isTest
--   isValidate
-- COMMAND LINE ARGS: NONE

require 'equalObjectValues'
require 'ifelse'
require 'isnan'
require 'isTensor'
require 'NamedMatrix'
require 'printAllVariables'
require 'printTableValue'
require 'printTableVariable'
require 'printTensorValue'
require 'splitString'
require 'torch'

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

-- randomly put 20% in test, 60% in train, 20% in validate
local function randomlyClassify()
   local r = torch.uniform(0, 1)
   if r < .2 then
      return 1, 0, 0  -- isTest
   elseif r < .8 then
      return 0, 1, 0  -- isTrain
   else
      return 0, 0, 1  -- isValidate
   end
end

local function randomlyClassifyTest()
   local vp = makeVp(0, 'randomlyClassifyTest')
   local nSamples = 10000
   local countIsTest, countIsTrain, countIsValidate = 0, 0, 0
   for i = 1, nSamples do
      local isTest, isTrain, isValidate = randomlyClassify()

      -- check that exactly one is set
      local sum = isTest + isTrain + isValidate
      local product = isTest * isTrain * isValidate
      assert(sum == 1)
      assert(product == 0)

      -- accumulate distributions 
      countIsTest = countIsTest + isTest
      countIsTrain = countIsTrain + isTrain
      countIsValidate = countIsValidate + isValidate
   end

   -- check rough distributions
   local totalCount = countIsTest + countIsTrain + countIsValidate
   assert(totalCount == nSamples)
   local fractionIsTest = countIsTest / totalCount
   local fractionIsTrain = countIsTrain / totalCount
   local fractionIsValidate = countIsValidate / totalCount
   vp(2, string.format('fractions isTest %f isTrain %f isValidate %f',
                       fractionIsTest, fractionIsTrain, fractionIsValidate))
   assert(.19 < fractionIsTest and fractionIsTest < .21)
   assert(.59 < fractionIsTrain and fractionIsTrain < .61)
   assert(.19 < fractionIsValidate and fractionIsValidate < .21)
end

-- create the info structure containing info.t and info.columnNames
local function makeInfo(nm)

   -- add column hasCOLUMN and hasNotCOLUMN to t
   local function makeHasHasnotColumns(nm, columnNames, t)

      -- fill in the has and hasNot columns for cIndex in the NamedMatrix
      local function makeHasHasNotColumn(i, cName, nm, columnNames, t)
         local vp, verbose = makeVp(0, 'makeHasHasNotColumn')
         local cIndex = i * 2 - 1
         vp(1, 'i', i, 'cName', cName)
         for sampleIndex = 1, nm.t:size(1) do
            local isPresent = not isnan(nm.t[sampleIndex][i])
            t[sampleIndex][cIndex] = ifelse(isPresent, 1, 0)
            t[sampleIndex][cIndex + 1] = ifelse(isPresent, 0, 1)
         end
         table.insert(columnNames, 'has' .. cName)
         table.insert(columnNames, 'hasNot' .. cName)
         if verbose > 0 then printTableValue('columnNames', columnNames) end
         if verbose > 0 then printTensorValue('t', t, t:size(1), t:size(2)) end
      end

      local cIndex = 1
      for i, cName in ipairs(nm.names) do
         print(string.format('examining column %s, %d of %d', cName, i, #nm.names))
         makeHasHasNotColumn(i, cName, nm, columnNames, t) -- mutate columnNames and t
         cIndex = cIndex + 2
      end
   end

   -- add columns isTest, isTrain, isValidate, isTestOrTrain to t
   local function makeTestTrainValidateColumns(nm, columnNames, t)
      local newColumnIndex = #columnNames + 1
      for sampleIndex = 1, nm.t:size(1) do
         local isTest, isTrain, isValidate = randomlyClassify()
         t[sampleIndex][newColumnIndex] = isTest
         t[sampleIndex][newColumnIndex + 1] = isTrain
         t[sampleIndex][newColumnIndex + 2] = isValidate
         t[sampleIndex][newColumnIndex + 3] = isTest + isTrain
      end
      table.insert(columnNames, 'isTest')
      table.insert(columnNames, 'isTrain')
      table.insert(columnNames, 'isValidate')
      table.insert(columnNames, 'isTestOrTrain')
   end

   assert(nm)
   local nSamples = nm.t:size(1)
   local nColumns = nm.t:size(2)
   local nIsColumns = 4
   local t = torch.Tensor(nSamples, nColumns * 2 + nIsColumns):fill(99) -- the marker 99 is for debugging
   local columnNames = {}

   makeHasHasnotColumns(nm, columnNames, t)

   print('spliting into test/train/validate')
   makeTestTrainValidateColumns(nm, columnNames, t)

   return {t=t, columnNames=columnNames}
end

local function makeInfoTest()
   local verbose = false
   torch.manualSeed(123)
   local nan = 0 / 0
   assert(isnan(nan))

   -- create the NamedMatrix
   local tensor = torch.Tensor{{11, 12}, {nan, 22}, {31, nan}, {nan, nan}}
   local names = {'a', 'b'}
   local levels = {}
   local nm = NamedMatrix{tensor=tensor, names=names, levels=levels}

   if verbose then 
      nm:print()
      printTensorValue('nm.t', nm.t, nm.t:size(1), nm.t:size(2))
   end

   -- create the info table
   local info = makeInfo(nm)
   if verbose then
      printTensorValue('info.t', info.t, info.t:size(1), info.t:size(2))
      printTableValue('info.columnNames', info.columnNames)
   end
   
   -- check shape of info elements
   assert(info.t:nDimension() == 2)
   assert(info.t:size(1) == 4)
   assert(info.t:size(2) == 8)
   assert(#info.columnNames == 8)
   
   -- check values in info.t
   local function rowEqual(rowIndex, seq)
      for i, value in ipairs(seq) do
         assert(info.t[rowIndex][i] == value)
      end
   end
   rowEqual(1, {1,0,1,0,0,1,0})
   rowEqual(2, {0,1,1,0,0,1,0})
   rowEqual(3, {1,0,0,1,0,1,0})
   rowEqual(4, {0,1,0,1,0,1,0})
   
   -- check values in info.columnNames
   local function elementEquals(actualSeq, expectedSeq)
      for i, actualValue in ipairs(actualSeq) do
         assert(actualValue == expectedSeq[i])
      end
   end
   elementEquals(info.columnNames, 
                 {'hasa', 'hasNota', 'hasb', 'hasNotb', 'isTest', 'isTrain', 'isValidate', 'isTestOrTrain'})
end

-- write the CSV header
-- write the info CSV file
-- info has two fields .t and .columnNames
local function writeOutput(info, outputFilePath)
   
   local function writeHeader(f, namesSeq)
      for i, name in ipairs(namesSeq) do
         if i > 1 then
            f:write(',')
         end
         f:write(name)
      end
      f:write('\n')
   end

   -- write all the rows to the output CSV file
   local function writeRows(f, tensor)
      
      -- write a row to the output CSV file
      local function writeRow(f, rowTensor)
         for i = 1, rowTensor:size(1) do
            if i > 1 then
               f:write(',')
            end
            local value = rowTensor[i]
            assert(value == 0 or value == 1)
            f:write(tostring(value))  -- all values are 0 or 1, so no loss or precision is possible
         end
         f:write('\n')
      end

      for rowIndex = 1, tensor:size(1) do
         writeRow(f, tensor[rowIndex])
      end
   end

   local vp, verboseLevel = makeVp(0, 'writeOutput')
   if verboseLevel > 0 then vp(1, '***') printTableValue('info', info) end
   local f, errMsg = io.open(outputFilePath, 'w')
   assert(f, errMsg)
   writeHeader(f, info.columnNames)
   writeRows(f, info.t)
   f:close()
end

local function truncateRows(nm, nRows)
   local vp = makeVp(0, 'truncateRows')
   local nColumns = nm.t:size(2) 
   local newT = torch.Tensor(nRows, nColumns)
   for r = 1, nRows do
      for c = 1, nColumns do
         newT[r][c] = nm.t[r][c]
      end
   end
   vp(1, 'newT', newT)
   return NamedMatrix{tensor=newT, names=nm.names, levels=nm.levels}
end

-- does info really encode the named matrix
local function check(nm, info, truncate)

   -- does info really encode the NaNs in the NamedMatrix?
   local function checkNans(nm, info)
      local vp, verboseLevel = makeVp(0, 'checkNans')
      assert(nm)
      assert(info)
      vp(1, 'nm', nm, 'info', info)
      if verboseLevel > 0 then printTensorValue('info.t', info.t) end
      local nSamples = nm.t:size(1)
      local nColumns = nm.t:size(2) 
      for r = 1, nSamples do
         for c = 1, nColumns do 
            local infoColumnIndex = 2 * c - 1
            local value = nm.t[r][c]
            vp(2, 'r', r, 'c', c, 'infoColumnIndex', infoColumnIndex, 'value', value)
            if isnan(value) then
               -- does not have the value
               assert(info.t[r][infoColumnIndex] == 0)
               assert(info.t[r][infoColumnIndex+1] == 1)
            else
               -- does have the value
               assert(info.t[r][infoColumnIndex] == 1)
               assert(info.t[r][infoColumnIndex+1] == 0)
            end
         end
      end
   end

   -- does info really encode which rows are test, train, and validate?
   local function checkRowSelection(info, truncate)
      local vp = makeVp(0, 'checkRowSelection')
      local cTrainOrTest = #info.columnNames
      local cValidate = cTrainOrTest - 1
      local cTrain = cValidate - 1
      local cTest = cTrain - 1

      local totalTest = 0
      local totalTrain = 0
      local totalValidate = 0
      local totalTrainOrTest = 0

      local nSamples = info.t:size(1)
      for rowIndex = 1, nSamples do
         local isTest = info.t[rowIndex][cTest]
         local isTrain = info.t[rowIndex][cTrain]
         local isValidate = info.t[rowIndex][cValidate]
         local isTrainOrTest = info.t[rowIndex][cTrainOrTest]
         vp(2, 'isTest', isTest, 'isTrain', isTrain, 'isValidate', isValidate, 'isTrainOrTest', isTrainOrTest)
         assert(isTest + isTrain + isValidate == 1)
         assert(isTest * isTrain * isValidate == 0)
         assert(isTrainOrTest == 0 or isTrainOrTest == 1)
         assert(isTrainOrTest == isTrain or isTest)
         totalTest = totalTest + isTest
         totalTrain = totalTrain + isTrain
         totalValidate = totalValidate + isValidate
      end

      local fractionTest = totalTest / nSamples
      local fractionTrain = totalTrain / nSamples
      local fractionValidate = totalValidate / nSamples
      vp(2, 'fractionTest', fractionTest, 'fractionTrain', fractionTrain, 'fractionValidate', fractionValidate)

      if not truncate then
         -- don't check range if the file is truncated, since too few samples to get a balanced distribution
         assert(.19 < fractionTest and fractionTest < .21, 'fractionTest=' .. tostring(fractionTest))
         assert(.59 < fractionTrain and fractionTrain < .61, 'fractionTrain=' .. tostring(fractionTrain))
         assert(.19 < fractionValidate and fractionValidate < .21, 'fractionValidate=' .. tostring(fractionValidate))
      end
   end

   -- does info have the right column names?
   local function checkColumnNames(nm, info)
      local vp, verboseLevel = makeVp(0, 'checkColumnNames')

      local nmNames = nm.names
      local infoNames = info.columnNames
      if verboseLevel > 0 then
         vp(1, '*****')
         printTableValue('nmNames', nmNames)
         printTableValue('infoNames', infoNames)
      end

      vp(2, '#nmNames', #nmNames, '#infoNames', #infoNames)
      assert(#nmNames * 2 + 4 == #infoNames)

      for i, nmName in ipairs(nmNames) do
         vp(2, 'nmName', nmName)
         assert(sequenceContains(infoNames, 'has' .. nmName))
         assert(sequenceContains(infoNames, 'hasNot' .. nmName))
      end

      assert(sequenceContains(infoNames, 'isTest'))
      assert(sequenceContains(infoNames, 'isTrain'))
      assert(sequenceContains(infoNames, 'isValidate'))
   end

   checkNans(nm, info)
   checkRowSelection(info, truncate)
   checkColumnNames(nm, info)
end

-------------------------------------------------------------------------------
-- MAIN PROGRAM
-------------------------------------------------------------------------------

local timer = Timer()
local vp, verboseLevel = makeVp(2, 'main')

-- configure
local testing = false
local truncate = false  -- if true, throw away most rows in the input NamedMatrix

-- identify input and output files
local inputFilePath = '../data/v6/output/parcels-sfr-geocoded.serialized-NamedMatrix'
local outputFilePath = '../data/v6/output/parcels-sfr-geocoded-info.csv'

-- assure replicability of random numbers
torch.manualSeed(123)  -- assure reproducability of the random numbers used

-- run unit tests
randomlyClassifyTest()
makeInfoTest()

-- make sure user didn't attempt to control us via the command line
assert(arg[1] == nil, 'this program does not use the command line')

-- read the input file
local nm = torch.load(inputFilePath)
if testing and false then nm:print() end
if truncate then
   local nRows = 2000
   local nRows = 3
   nm = truncateRows(nm, nRows)
   if verbose and false then nm:print() end
end

-- build and check the info table
local info = makeInfo(nm)
assert(info.t)
assert(info.columnNames)

print('starting to check results')
check(nm, info, truncate)

-- write the info table
writeOutput(info, outputFilePath)

local cpu, wallclock = timer:cpuWallclock()
print(string.format('seconds cpu %f wallclock %f', cpu, wallclock))

assert(not testing, 'reset testing flag and run again for production output')
assert(not truncate, 'reset truncate flag and run again for production output')

print('done')
