-- split-all.lua
-- Split inputs/obs-OBS-all-NAME.csv into output/obs-OBS-TT-NAME.csv
-- where 
-- NAME in {apns,dates,features,prices}
-- OBS  in {obs1A,obs2R}
-- TT   in {train,test}
-- First drop an duplicate records in the input: duplicate mean the features
-- are all the same.

require 'all'

-------------------------------------------------------------------------------
-- FUNCTIONS
-------------------------------------------------------------------------------

function readInput(is1D, obs, name, options, log)
   -- read input csv file with one or more columns of data
   -- respect options.test and limit input
   -- RETURNS
   -- tensor : 1D Tensor or 2D Tensor

   local v = makeVerbose(false, 'readInput')

   affirm.isBoolean(is1D, 'is1D')
   affirm.isString(obs, 'obs')
   affirm.isString(name, 'name')
   affirm.isTable(options, 'options')

   local csv = CsvUtils()

   local inFilePath = 
      options.dataDir .. 'v5/inputs/obs' .. obs .. '-all-' .. name .. '.csv'
   log:log('reading input file %s', inFilePath)
   local hasHeader = true
   local inputLimit = 0
   if options.test == 1 then inputLimit = 1000 end

   local values, header
   if is1D then
      values, header = csv:read1Number(inFilePath,
                                       hasHeader,
                                       '1D Tensor',
                                       inputLimit)
   else
      values, header = csv:readNumbers(inFilePath,
                                       hasHeader,
                                       '2D Tensor',
                                       inputLimit)
      v('read 2D')
      v('values', values)
      v('header', header)
   end
      
   return values
end -- readInput
 
function read1D(obs, name, options, log)
   -- read csv file with one numeric column of data
   -- respect options.test and limit input
   -- RETURNS
   -- tensor : 1D Tensor

   affirm.isString(obs, 'obs')
   affirm.isString(name, 'name')
   affirm.isTable(options, 'options')
   affirm.isTable(log, 'log')
   
   local is1D = true
   return readInput(is1D, obs, name, options, log)
end -- read1D

function read2D(obs, name, options, log)
   -- read csv file with many columns of data
   -- RETURNS
   -- tensor : 2D Tensor

   
   affirm.isString(obs, 'obs')
   affirm.isString(name, 'name')
   affirm.isTable(options, 'options')

   local is1D = false
   return readInput(is1D, obs, name, options, log)
end -- read2D

function readData(obs, options, log)
   -- RETURNS
   -- n    : number of observations 
   -- data : table with components of the observations
   local v, isVerbose = makeVerbose(true, 'readData')
   verify(v, isVerbose,
          {{obs, 'obs', 'isString'},
           {options, 'options', 'isTable'},
           {log, 'log', 'isTable'}})
   data = {}
   data.apns = read1D(obs, 'apns', options, log)
   data.dates = read1D(obs, 'dates', options, log)
   data.features = read2D(obs, 'features', options, log)
   data.prices = read1D(obs, 'prices', options, log)

   v('data.features', data.features)
   v('data.features:size()', data.features:size())

   log:log('read obs %s name %s records %d', 
           obs, 'apns', data.apns:size(1))
   log:log('read obs %s name %s records %d', 
           obs, 'dates', data.dates:size(1))
   log:log('read obs %s name %s records %d', 
           obs, 'features', data.features:size(1))
   log:log('read obs %s name %s records %d', 
           obs, 'prices' , data.prices:size(1))

   local n = data.apns:size(1)
   assert(n == data.dates:size(1))
   assert(n == data.features:size(1))
   assert(n == data.prices:size(1))

   return n, data
end -- readData

function selected(selected, data)
   -- return observervations in data selected by 0/1 1D Tensor selected
   -- RETURNS
   -- n        : number of observations selected
   -- selected : table with just the selected observations
   local selected = {}
   selected.apns = {}
   selected.dates = {}
   selected.features = {}
   selected.prices = {}
   
   local countSelected = 0
   for i = 1, selected:size(1) do
      if selected[i] == 1 then
         countSelected = countSelected + 1
         selected.apns[countSelected] = data.apns[i]
         selected.dates[countSelected] = data.dates[i]
         selected.features[countSelected] = data.featues[i]
         selected.prices[countSelected] = data.prices[i]
      end
   end
   
   return countSelected, selected
end -- selected

function writeTensor(tensor, name, selected, tt, options, obs, log)
   -- write Tensor to cvs without the header
   
   affirm.isTensor(tensor, 'tensor')
   affirm.isString(name, 'name')
   affirm.isTensor1D(selected, 'selected')
   affirm.isString(tt, 'tt')
   affirm.isTable(options, 'options')
   affirm.isString(obs, 'obs')

   -- open the file
   local fileName = obs .. '-' .. tt .. '-' .. name .. '.csv'
   local filePath = options.dataDir .. 'v5/outputs/' .. fileName
   local file, err = io.open(filePath, 'w')
   if file == nil then
      error('failed to open file; error = ' .. err)
   end

   -- write the records
   local nDim = tensor:nDimension()
   assert(nDim == 1 or nDim == 2)
   local countWritten = 0
   for i = 1, tensor:size(1) do
      if selected[i] == 1 then
         if nDim == 1
         then
            file:write(tostring(tensor[i]))
            file:write('\n')
         else
            for j = 1, tensor:size(2) do
               if j > 1 then file:write(',') end
               file:write(tostring(tensor[i][j]))
            end
            file:write('\n')
         end
         countWritten = countWritten + 1
      end -- handling of a selected observation
   end -- loop through observations

   -- close the file
   file:close()

   log:log('wrote %d records to file %s', countWritten, fileName)
end -- writeTensor
   
function writeSelected(data, selected, tt, options, obs, log)
   -- write selected observations in data to named files in output
   -- write OBS-TT-NAME-WHICH.csv
   -- ARGS
   -- data     : table containing input Tensors
   -- selected : 1D 0-1 Tensor; 1 indicates observation is to be written
   -- tt       : string in {test,train}
   --            used to compose file name written
   -- options  : table

   local v = makeVerbose(false, 'writeSelected')
   v('data', data)
   v('tt', tt)
   v('selected', selected)

   affirm.isTable(data, 'data')
   affirm.isTensor1D(selected, 'selected')
   affirm.isString(tt, 'tt')
   affirm.isTable(options, 'options')
   affirm.isString(obs, 'obs')

   writeTensor(data.apns, 'apns', selected, tt, options, obs, log)
   writeTensor(data.dates, 'dates', selected, tt, options, obs, log)
   writeTensor(data.features, 'features', selected, tt, options, obs, log)
   writeTensor(data.prices, 'prices', selected, tt, options, obs, log)
end -- writeSelected

function dropDuplicates(nObs, data, log)
   -- examine every pair of records and drop duplicates based on data.features
   -- ARGS
   -- n    : integer; number of records
   -- data : table
   local v, isVerbose = makeVerbose(false, 'dropDuplicates')
   verify(v, isVerbose,
          {{nObs, 'nObs', 'isIntegerPositive'},
           {data, 'data', 'isTable'}})

   -- 1. Find the duplicates, retaining the first such
   local keep = torch.Tensor(nObs):fill(1)
   -- determine number of comparisons, assuming no duplicates are found
   -- each duplicate slightly reduces the computed nComparisons
   local nComparisons = nObs * (1 + nObs - 1) / 2  -- (a1 + an) * n / 2
   local done = 0
   local tc = TimerCpu()
   v('data.features', data.features)
   local nDims = data.features:size(2)
   for i = 1, nObs - 1 do
      if keep[i] == 1 then
         collectgarbage()
         local baseVector = data.features[i]
         local base = torch.Tensor(nObs, nDims)
         local index = 0
         for j =  1, nObs do
            index = index + 1
            base[index] = baseVector
         end
         local equalElements = torch.eq(base, data.features)
         v('i', i)
         v('base', base)
         v('data.features', data.features)
         v('equalElements', equalElements)
         v('base size', base:size())
         v('equalElements size', equalElements:size())
         for j = i + 1, nObs do
            done = done + 1
            local equal = equalElements[j]
            v('j', j)
            if torch.sum(equal) == nDims then
               local s = 'APNs are the same'
               if data.apns[i] ~= data.apns[j] then
                  s = string.format('apn1 = %d apn2 = %d',
                                    data.apns[i], data.apns[j])
               end
               log:log('%d and %d are equal %s', i, j, s)
               --print('baseVector', baseVector)
               --print('equal', equal)
               keep[j] = 0
            end
         end
         v('keep', keep)
         --if i >= 5 then halt() end
      end
      -- this code is too slow
      if false and keep[i] == 1 then
         for j = i + 1, n do
            collectgarbage()
            done = done + 1
            local other = data.features[j]
            local equalElements = torch.eq(base, other)
            if n == torch.sum(equalElements) then
               print(string.format('%d and %d are equal', i, j))
               print('base', base)
               print('other', other)
               keep[j] = 0
            end
         end
      end
      if i % 10000 == 0 then
         local cumSecs = tc:cumSeconds()
         print(string.format('i=%d: up to %g of %g comparisons in %f CPU secs', 
                             i, done, nComparisons, cumSecs))
         print(string.format(' %f CPU hours to go',
                             cumSecs * (nComparisons / done) / (60 * 60)))
                             
      end
      --if i >= 10 then halt() end
   end

   -- 2. Delete the duplicates
   log:log('Keeping %d of %d observations', torch.sum(keep), nObs)
   log:log(' hence dropping %d duplicate observations', nObs - torch.sum(keep))

   local newData = {}
   local newN = torch.sum(keep)
   newData.apns = torch.Tensor(newN)
   newData.dates = torch.Tensor(newN)
   newData.features = torch.Tensor(newN, data.features:size(2))
   newData.prices = torch.Tensor(newN)
   local index = 0
   for i = 1, nObs do
      if keep[i] == 1 then
         index = index + 1
         newData.apns[index] = data.apns[i]
         newData.dates[index] = data.dates[i]
         newData.features[index] = data.features[i]
         newData.prices[index] = data.prices[i]
      end
   end
   v('newData', newData)
   return newN, newData
end -- dropDuplicates

function assertVectorEqual(a, b)
   assert(a:size(1), b:size(1))
   for i = 1, a:size(1) do
      assert(a[i] == b[i])
   end
end -- assertVectorEqual

function dropDuplicatesTest()
   -- unit test of dropDuplicate
   local v = makeVerbose(true, 'dropDuplicatesTest')
   local log = Log('/tmp/split-all:dropDuplicatesTest')
   local nObs = 10
   local nDims = 3
   local data = {}
   data.apns = torch.rand(nObs)
   data.dates = torch.rand(nObs)
   data.features = torch.rand(nObs, nDims)
   data.features[3] = data.features[2]
   data.features[9] = data.features[2]
   data.features[7] = data.features[4]
   data.prices = torch.rand(nObs)
   local newN, newData = dropDuplicates(nObs, data, log)
   assert(newN == 7)
   v('data.features', data.features)
   v('newData.features', newData.features)
   -- check that rows 3, 7, 9 were dropped
   assertVectorEqual(data.features[1], newData.features[1])
   assertVectorEqual(data.features[2], newData.features[2])
   assertVectorEqual(data.features[4], newData.features[3])
   assertVectorEqual(data.features[5], newData.features[4])
   assertVectorEqual(data.features[6], newData.features[5])
   assertVectorEqual(data.features[8], newData.features[6])
   assertVectorEqual(data.features[10], newData.features[7])
   --halt()
end -- dropDuplicatesTest
   


function split(options)
   -- split inputs for the observations set after dropping observations
   -- that have duplicate features
   -- ARGS
   -- options     : table of command line options
   -- options.obs : observation set to split
   -- options.log : Log object

   local v = makeVerbose(false, 'split')

   affirm.isTable(options, 'options')
   affirm.isString(options.obs, 'options.obs')
   affirm.isTable(options.log, 'options.log')

   local obs = options.obs
   local log = options.log

   affirm.isString(obs, 'obs')
   affirm.isLog(log, 'log')

   local n, data = readData(obs, options, log)

   local n, data = dropDuplicates(n, data, log)

   local randoms = torch.rand(n)  -- sample from uniform(0,1)
   
   local selectedTest = torch.lt(randoms, options.toTest)
   local nSelectedTest = torch.sum(selectedTest)
   log:log('num test transactions = %d', nSelectedTest)

   local selectedTrain = torch.ge(randoms, options.toTest)
   local nSelectedTrain = torch.sum(selectedTrain)
   log:log('num training transactions = %d', nSelectedTrain)

   assert(nSelectedTrain > nSelectedTest) -- for now
   assert(torch.sum(selectedTest + selectedTrain) == n)
   
   v('obs', obs)
   v('randoms', randoms)
   v('selectedTest', selectedTest)
   v('num selectedTest', torch.sum(selectedTest))
   v('selectedTrain', selectedTrain)
   v('num selectedTrain', torch.sum(selectedTrain))

   writeSelected(data, selectedTest, 'test', options, obs, log)
   writeSelected(data, selectedTrain, 'train', options, obs, log)
end -- split

   
--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

print('***********************************************************************')

local v = makeVerbose(true, 'main')
local options = 
   mainStart(arg, 
             'split input files into train, test files',
             {{'-dataDir', '../../data/', 'path to data directory'},
              {'-obs', '', '1A or 2R'},
              {'-seed', 27, 'random number seed'},
              {'-test', 1, '0 for production, 1 to test'},
              {'-toTest', .2, 'fraction to test set'}})

v('options', options)

-- check required parameters
assert(options.obs ~= '', '-opt must be supplied')
assert(options.obs == '1A' or options.obs == '2R',
       '-obs in {"1A", "2R"}')

local log = options.log   

-- test tricky functions
dropDuplicatesTest()

-- validate options
assert(options.test == 0 or options.test == 1)
assert(options.toTest > 0)
assert(options.toTest < 1)

if options.test == 1 then
   log:log('TESTING')
end

setRandomSeeds(options.seed)

split(options)

mainEnd(options)

