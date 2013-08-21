-- readTrainingData.lua


require 'affirm'
require 'CsvUtils'
require 'Log'
require 'makeVerbose'
require 'verify'

local function hasPrefix(name, prefixes)
   for _, prefix in ipairs(prefixes) do
      if string.sub(name, 1, string.len(prefix)) == prefix then
         return true
      end
   end
   return false
end -- hasPrefix 

local function ne(c1, c2)
   -- return true if at least one element differs
   -- otherwise halt 
   local v = makeVerbose(false, 'ne')
   assert(c1:size(1) == c2:size(1))
   for i = 1, c1:size(1) do
      v('i,c1,c2', i, c1[i], c2[i])
      if c1[i] ~= c2[i] then
         return true
      end
   end
   error('same in each element')
end

local function extractColumn(values, colNames, colName)
   for colIndex = 1, #colNames do
      if hasPrefix(colNames[colIndex], {colName}) then
         local result = torch.Tensor(values:size(1))
         for obsIndex = 1, values:size(1) do
            result[obsIndex] = values[obsIndex][colIndex]
         end
         return result
      end
   end
   error('bad colName = ' .. tostring(colName))
end -- extractColumn

local function countCodes(values, colNames, prefix)
   -- print number of times each foundation code is selected
   local v = makeVerbose(false, 'countCodes')
   local grandSum = 0
   for colIndex = 1, #colNames do
      if hasPrefix(colNames[colIndex], {prefix}) then
         local count = 0
         for obsIndex = 1, values:size(1) do
            count = count + values[obsIndex][colIndex]
         end
         v(string.format('column %s is selected %d times',
                         colNames[colIndex], count))
         grandSum = grandSum + count
      end
   end
   v('grand sum across indicator columns', grandSum)
   assert(grandSum == values:size(1))
   -- halt()
end -- countCodes

local function checkFoundationCodes(values, colNames)
   -- do they sum to 1 in each observation?
   for obsIndex = 1, values:size(1) do
      local sum = 0
      for colIndex = 1, #colNames do
         if hasPrefix(colNames[colIndex], {'FOUNDATION-CODE'}) then
            local value = values[obsIndex][colIndex]
            assert(value == 0 or value == 1)
            sum = sum + value
         end
      end
      assert(sum == 1)
   end
   -- is one column exactly equal to another?
   -- NOTE: if using a test set (with 1000 values), this test can fail
   -- and does fail for obs 1A
   local c1 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-001')
   local c2 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-CRE')
   local c3 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-MSN')
   local c4 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-PIR')
   local c5 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-RAS')
   local c6 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-SLB')
   local c7 = extractColumn(values, colNames, 'FOUNDATION-CODE-is-UCR')
   ne(c1,c2)  -- this one fails on obs1A first 1000 transactions
   ne(c1,c3) 
   ne(c1,c4) 
   ne(c1,c5) 
   ne(c1,c6) 
   ne(c1,c7)
   
   ne(c2,c3) 
   ne(c2,c4) 
   ne(c2,c5) 
   ne(c2,c6) 
   ne(c2,c7)

   ne(c3,c4) 
   ne(c3,c5) 
   ne(c3,c6) 
   ne(c3,c7)

   ne(c4,c5) 
   ne(c4,c6) 
   ne(c4,c7)
   
   ne(c5,c6)
   ne(c5,c7)
       
   ne(c6,c7)
end -- checkFoundationCodes

local function kept(keep)
   -- return count of keep[i] == true
   local count = 0
   for i = 1, #keep do
      if keep[i] then
         count = count + 1 
      end
   end
   return count
end -- kept

local function keepColumns(values, keep)
   -- remove certain columns from values, a 2D Tensor
   -- keep[colIndex] == true ==> keep colIndex in result
   local v = makeVerbose(false, 'readTrainingData::keepColumns')
   v('keep', keep)  -- BUG: doesn't work with call to v instead of print
   v('values:size(2)', values:size(2))
   v('kept(keep)', kept(keep))
   local result = torch.Tensor(values:size(1), kept(keep))
   v('result:size()', result:size())
   local resultColIndex = 0
   for colIndex = 1, values:size(2) do
      if keep[colIndex] then
            resultColIndex = resultColIndex + 1
            for obsIndex = 1, values:size(1) do
               result[obsIndex][resultColIndex] = values[obsIndex][colIndex]
            end
      end
   end
   return result
end -- keepColumns


local function dropColumns(values, colNames, withPrefixes)
   -- remove columns with the prefix
   -- RETURN
   -- new 2D Tensor of values
   -- names of columns kept
   local v = makeVerbose(false, 'readTrainingData::dropColumns')
   v('colNames', colNames)
   v('withPrefixes', withPrefixes)
   assert(#colNames == values:size(2))
   local keep = {}
   local keptColNames = {}
   for colIndex = 1, values:size(2) do
      local colName = colNames[colIndex]
      if hasPrefix(colName, withPrefixes) then
         keep[colIndex] = false
      else
         keep[colIndex] = true
	 keptColNames[#keptColNames + 1] = colName
      end
   end
   local newValues = keepColumns(values, keep)
   return newValues, keptColNames
end -- dropColumns

local function checkForEqualFeatureRows(features, featureNames)
   print('check for equal feature rows')
   local suspectedEqual = {70093, 70094, 70095, 70096, 70098, 70099}
   local baseIndex = suspectedEqual[1]
   print('baseIndex', baseIndex)
   for i = 2, #suspectedEqual do
      local obsIndex = suspectedEqual[i]
      print('obsIndex', obsIndex)
      local allSame = true
      for j = 1, features:size(2) do
         if features[baseIndex][j] ~= features[obsIndex][j] then
            allSame = false
            print('found difference in those suspected to be equal')
            print('basedIndex', baseIndex)
            print('j', j)
            print('features[baseIndex][j]', features[baseIndex][j])
            print('features[obsIndex][j]', features[obsIndex][j]) 
         end
      end
      print(string.format('%d and %d are the same', baseIndex, obsIndex))
   end
   -- from previous runs, we know they are all the same
   -- print key fields
   local base = features[baseIndex]
   printField(base, 
   
   halt()
end -- checkForEqualFeatureRows

local function readFeatureColumnNames(options)
   local v, isVerbose = makeVerbose(true, 'readTrainingData::readFeatureColumnsNames')
   verify(v, isVerbose,
	  {{options, 'options', 'isTable'}})

   -- read header from input files, since it was dropped at the split

   local inFilePath = 
      options.dataDir .. 
      '/v5/inputs/obs' .. 
      options.obs .. 
      '-all-features.csv'
   v('inFilePath', inFilePath)
   local _, header = CsvUtils():readNumbers(inFilePath,
                                            true,   -- has header
                                            '2D Tensor',
                                            1)      -- 1 data records
   v('header', header)

   -- build sequence of column names
   colNames = {}
   for colName in string.gmatch(header, '[^,]+') do
      colNames[#colNames + 1] = colName
   end

   return colNames
end -- readFeatureColumnNames

local function dropFeatures(values, options, log)
   -- return values with the last -is- field removed
   -- if options.debug ~= 0 then drop some 1 of k features
   local v = makeVerbose(true, 'readTrainingData::dropFeatures')

   -- translate options.debug into local semantics
   -- so that the options.debug codes can be reused
   local debug = nil 
   if options.debug == 3 then
      debug = 'check encoding' -- make sure values are actual 1-of-K encoded
   elseif options.debug == 1 then
      debug = 'drop all 1 of k'
   elseif options.debug == 2 then
      debug = 'drop some 1 of k'
   end

   v('values', values)
   v('log', log)

   colNames = readFeatureColumnNames(options)

   if debug == 'drop all 1 of k' then
      -- drop all 1 of K features, in search for collinearity

      -- determine column indices of columns with 1-in-K encoding
      local specialColumnPrefixes
      if debug == 'drop all 1 of K' then
         -- drop all 1 of K
         local newValues =  dropColumns(values,
                                        colNames,
                                        {'FOUNDATION-CODE',
                                         'HEATING-CODE',
                                         'LOCATION-INFLUENCE-CODE',
                                         'PARKING-TYPE-CODE',
                                         'POOL-FLAG',
                                         'ROOF-TYPE-CODE',
                                         'TRANSACTION-TYPE-CODE'})
         print('newValues:size()', newValues:size())
         --halt()
         return newValues
      end
   elseif debug == 'drop some 1 of k'  then
      -- drop all of 1 of K except FOUNDATION-CODE non-colinear
      -- drop all the foundation codes for now
      -- then include just one of them
      countCodes(values, colNames, 'FOUNDATION-CODE')
      countCodes(values, colNames, 'HEATING-CODE')
      countCodes(values, colNames, 'LOCATION-INFLUENCE-CODE')
      countCodes(values, colNames, 'PARKING-TYPE-CODE')
      countCodes(values, colNames, 'POOL-FLAG')
      countCodes(values, colNames, 'ROOF-TYPE-CODE')
      countCodes(values, colNames, 'TRANSACTION-TYPE-CODE')
      --halt()
      checkFoundationCodes(values, colNames) -- sum to 1?
      local newValues = dropColumns(values,
                                    colNames,
                                    {--'FOUNDATION-CODE-is-001',
                                     --'FOUNDATION-CODE-is-CRE',
                                     'FOUNDATION-CODE-is-MSN',
                                     --'FOUNDATION-CODE-is-PIR',
                                     --'FOUNDATION-CODE-is-RAS',
                                     --'FOUNDATION-CODE-is-SLB',
                                     --'FOUNDATION-CODE-is-UCR',
                                     'HEATING-CODE-is-ST0',
                                     'LOCATION-INFLUENCE-CODE-is-I01',
                                     'PARKING-TYPE-CODE-is-ASP',
                                     'POOL-FLAG-is-1',
                                     'ROOF-TYPE-CODE-is-F00',
                                     'TRANSACTION-TYPE-CODE-is-3'})
      print('values:size()', values:size())
      print('newValues:size()', newValues:size())
      return newValues
   elseif debug == 'check encoding' then
      -- affirm 1 of K encoding
      -- Result: this test showed that 1 of K encoding is used in all
      -- the relevant columns of obs 1A and 2R
      local function check1OfK(v, colNames, prefix)
         local sum = 0
         local found = false
         for d, colName in ipairs(colNames) do
            if string.sub(colName, 1, string.len(prefix)) == prefix then
               sum = sum + v[d]
               found = true
            end
         end
         if found then
            assert(sum == 1, prefix)
         end
      end
      
      for obsIndex = 1, values:size(1) do
         local v = values[obsIndex]
         check1OfK(v, colNames, 'FOUNDATION-CODE')
         check1OfK(v, colNames, 'HEATING-CODE')
         check1OfK(v, colNames, 'LOCATION-INFLUENCE-CODE')
         check1OfK(v, colNames, 'PARKING-TYPE-CODE')
         check1OfK(v, colNames, 'ROOF-TYPE-CODE')
         check1OfK(v, colNames, 'TRANSACTION-TYPE-CODE')
         print('obsIndex', obsIndex)
      end
      halt()
   end -- debugging code

   local newValues, keptColNames = dropColumns(
      values, 
      colNames,
      {'FOUNDATION-CODE-is-MSN',
       'HEATING-CODE-is-ST0',
       'LOCATION-INFLUENCE-CODE-is-I01',
       'PARKING-TYPE-CODE-is-ASP',
       'POOL-FLAG-is-1',
       'ROOF-TYPE-CODE-is-F00',
       'TRANSACTION-TYPE-CODE-is-3'})
   globalFeatureColumnNames = keptColNames
   v('globalFeatureColumnNames', globalFeatureColumnNames)
   v('values:size()', values:size())
   v('newValues:size()', newValues:size())
   --halt()
   return newValues
end -- dropFeatures

local function read(nDimensions, name, options, log)
   local v = makeVerbose(true, 'readTrainingData::read')
   v('options', options)

   local csv = CsvUtils()
   
   local inFilePath = 
      options.dataDir .. 
      'v5/outputs/' .. 
      'obs' .. options.obs .. 
      '-train-' ..  name .. 
      '.csv'
   
   log:log('reading input file %s', inFilePath)
   local hasHeader = false
   
   local values
   if nDimensions == 1 then
      values = csv:read1Number(inFilePath,
                               hasHeader,
                               '1D Tensor',
                               options.inputLimit)
   elseif nDimensions == 2 then
      values = csv:readNumbers(inFilePath,
                               hasHeader,
                               '2D Tensor',
                               options.inputLimit)
      v('read header', header)
   else
      error('bad nDimensions = ' .. tostring(nDimensions))
   end

   log:log('read %d data records', values:size(1))
   
   return values
end -- read

function readTrainingData(options, log, dropRedundant)
   -- read the training data into a table of Tensors
   -- validate that each file has same number of observations
   -- ARGS
   -- dataDir       : string, path to data directory
   -- log           : Log instance
   --                 log file names and number of data records
   -- inputLimit    : integer >= 0
   --                 if == 0, read all the records
   --                 otherwise read only inputLimit records
   -- obs           : string in {1A,2R}
   --                 which observation set to read
   -- dropRedundant : boolean
   --                 if true, drop one of the 1-of-K features
   --                 (so that linear regression matrix is not singular)
   -- RETURNS
   -- n             : number of observations 
   -- data          : table with components of the observations; components
   --                 data.apns     : 1D Tensor
   --                 data.dates    : 1D Tensor
   --                 data.features : 2D Tensor
   --                 data.prices   : 1D Tensor
   --                 date.featureNames : sequence of strings

   local v, isVerbose = makeVerbose(true, 'readTrainingData')

   verify(v,
          isVerbose,
          {{options, 'options', 'isTable'},
           {log, 'log', 'isTable'},
           {dropRedundant, 'dropRedundant', 'isBoolean'}})

   -- verify fields used in options
   affirm.isString(options.dataDir, 'options.dataDir')
   affirm.isInteger(options.inputLimit, 'options.inputLimit')
   affirm.isString(options.obs, 'options.obs')

   -- verify values of options
   if not (options.obs == '1A' or options.obs == '2R') then
      error('options.obs must be 1A or 2R; opions.obs = ' .. options.obs)
   end



   data = {}
   data.apns = read(1, 'apns', options, log)
   data.dates = read(1, 'dates', options, log)
   data.features = read(2, 'features', options, log)
   data.prices = read(1, 'prices', options, log)
   
   
   if dropRedundant then
      log:log('dropping redundant features')
      data.features = dropFeatures(data.features, options, log)
   else
      log:log('did not drop redundant features')
      -- TODO: the column names should be an output, not a global var
      globalFeatureColumnNames = readFeatureColumnNames(options)
   end
   data.featureNames = globalFeatureColumnNames

   local n = data.apns:size(1)
   assert(n == data.dates:size(1))
   assert(n == data.features:size(1))
   assert(n == data.prices:size(1))

   assert(#data.featureNames == data.features:size(2))

   if options.debug == 4 then
      checkForEqualFeatureRows(data.features, data.featureNames)
   end

   return n, data
end -- readTrainingData

