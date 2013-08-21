-- Dataframe_test.lua
-- unit test of class Dataframe

require 'isnan'
require 'Dataframe'
require 'makeVp'
require 'sequenceContains'

verbose = 0
local vp = makeVp(verbose)

-- make test data

local NA = Dataframe.NA
local value1 = {1, 2, 1, NA}                     -- a factor seq
local level1 = {"first", "second"}
local value2 = {"c", "b", "a", NA}               -- a string seq
local value3 = {10.0, 20.0, 30.0, NA}            -- a number seq

local values = {factorValue = value1,
                stringValue = value2,
                numberValue = value3}

local levels = {factorValue = level1}

-- test construction and accessors

local df1 = Dataframe {values = values, levels = levels}
--print("df1"); df1:print()

local df2 = Dataframe {values = values}

-- onlyRows
local selected = {true, false, true, false}
local dfSubset = df1:onlyRows(selected)
--print('df1'); print(df1)
--print('dfSubset'); print(dfSubset)
assert(dfSubset:nRows() == 2)
assert(dfSubset:nCols() == 3)
assert(dfSubset:get('factorValue', 1) == 1)
assert(dfSubset:get('numberValue', 1) == 10)
assert(dfSubset:get('numberValue', 2) == 30)
assert(dfSubset:kind('numberValue') == 'number')
assert(dfSubset:kind('factorValue') == 'factor')

-- row
vp(1, 'df1', df1)
local df1Row = df1:row(2)
vp(1, 'df1Row', df1Row)
assert(df1Row:nRows() == 1)
assert(df1Row:nCols() == df1:nCols())
assert(df1Row:get('factorValue', 1) == 2)
assert(df1Row:get('numberValue', 1) == 20)
assert(df1Row:get('stringValue', 1) == 'b')

-- columnsNames
local function contains(seq, e) 
   for k,v in pairs(seq) do
      --print('v ' .. v)
      if v == e then 
         return true 
      end
   end
   return false
end

names = df1:columnNames()
--print('columnNames'); print(names)
assert(contains(names, 'factorValue'))
assert(contains(names, 'stringValue'))
assert(contains(names, 'numberValue'))

-- numberColumnNames
--print(df1); df1:print()
numberNames = df1:numberColumnNames()
assert(not contains(numberNames, 'factorValue'))
assert(not contains(numberNames, 'stringValue'))
assert(contains(numberNames, 'numberValue'))

-- factorColumnNames
factorNames = df1:factorColumnNames()
assert(contains(factorNames, 'factorValue'))
assert(not contains(factorNames, 'stringValue'))
assert(not contains(factorNames, 'numberValue'))

-- stringColumnNames
stringNames = df1:stringColumnNames()
assert(not contains(stringNames, 'factorValue'))
assert(contains(stringNames, 'stringValue'))
assert(not contains(stringNames, 'numberValue'))


-- isFactor

assert("factor" == df1:kind("factorValue"))
assert("string" == df1:kind("stringValue"))
assert("number" == df1:kind("numberValue"))

assert("number" ==  df2:kind("factorValue"))  -- since no levels supplied

-- get
function isNA(x) return x == Dataframe.NA end

assert(1 == df1:get("factorValue", 1))
assert("b" == df1:get("stringValue", 2))
assert( 30.0 == df1:get("numberValue", 3))

--print("df1"); df1:print()
assert(isNA(df1:get("factorValue", 4)))
assert(isNA(df1:get("stringValue", 4)))
assert(isNA(df1:get("numberValue", 4)))

-- level
assert("first" == df1:level("factorValue", 1))
assert("second" == df1:level("factorValue", 2))
assert("first" == df1:level("factorValue", 3))

-- kind
assert("factor" == df1:kind("factorValue"))
assert("string" == df1:kind("stringValue"))
assert("number" == df1:kind("numberValue"))

-- nRows
assert(4 == df1:nRows())
assert(0 == Dataframe.newEmpty():nRows())
assert(0 == Dataframe.newEmpty():nCols())

-- nCols
assert(3 == df1:nCols())

-- writeCsv
local testFileName = "Dataframe_test_df1.csv"
df1:writeCsv{file=testFileName}

-- newFromFile and get
local df = Dataframe.newFromFile{file = testFileName, verbose=0}
--print('df with stringsAsFactors=true'); df:print(df)
assert(df:get('factorValue', 1) == 1)
assert(df:get('factorValue', 2) == 2)
assert(df:get('factorValue', 3) == 1)
assert(df:get('factorValue', 4) == Dataframe.NA)
assert(df:get('numberValue', 2) == 20)
assert(df:get('stringValue', 3) == 3)
assert(df:kind('factorValue') == 'factor')
assert(df:kind('numberValue') == 'number')
assert(df:kind('stringValue') == 'factor')

-- newFromFile with stringsAsFactors == false
local df = Dataframe.newFromFile{file= testFileName, stringsAsFactors=false}
--print('df with stringsAsFactors=false'); df:print(df)
assert(df:kind('factorValue') == 'string')
assert(df:kind('numberValue') == 'number')
assert(df:kind('stringValue') == 'string')

-- newFromFile2
local df = Dataframe.newFromFile2{file=testFileName,
                                  numberColumns={'numberValue'},
                                  stringColumns={'stringValue'},
                                  factorColumns={'factorValue'}}
--print('df'); df:print()
assert(df:nRows() == 4)
assert(df:nCols() == 3)
assert(df:kind('numberValue') == 'number')
assert(df:kind('stringValue') == 'string')
assert(df:kind('factorValue') == 'factor')
assert(df:get('numberValue', 1) == 10)
assert(df:get('numberValue', 4) == Dataframe.NA)
assert(df:get('stringValue', 2) == 'b')
assert(df:get('factorValue', 3) == 1)
assert(df:level('factorValue', 3) == 'first')

-- asTensor (2D)
local df = Dataframe.newFromFile{file = testFileName}
local t, levels = df:asTensor({"factorValue", "numberValue"})
--print('df'); df:print{}
--print('t'); print(t)
--print('level'); print(levels)
assert(t:nDimension() == 2)
assert(t:size(1) == 4)
assert(t:size(2) == 2)
assert(t[1][1] == 1)
assert(t[2][1] == 2)
assert(t[3][1] == 1)
assert(isnan(t[4][1]))
assert(t[1][2] == 10)
assert(t[2][2] == 20)
assert(t[3][2] == 30)
assert(isnan(t[4][2]))

-- asTensor (1D)
local df = Dataframe.newFromFile{file = testFileName}
local t, levels = df:asTensor{"factorValue"}
vp(1, 't', t)
vp(1, 'levels', levels)
assert(t:dim() == 1)
assert(t:size(1) == 4)
assert(t[1] == 1)
assert(t[2] == 2)
assert(t[3] == 1)
assert(isnan(t[4]))

-- dropColumns
local df = Dataframe.newFromFile{file = testFileName}
local dfTest = df:dropColumns{'factorValue', 'numberValue'}
assert(dfTest:nCols() == 1)
assert('stringValue' == dfTest:columnNames()[1])

-- onlyColumns
local vp, verbose = makeVp(0)
local df = Dataframe.newFromFile{file = testFileName}
if verbose >= 1 then df:print{name='df'} end
local dfTest = df:onlyColumns{'factorValue', 'numberValue'}
local namesTest = dfTest:columnNames()
if verbose >=1 then dfTest:print{name='dfTest'} end
assert(#namesTest == 2)
local function contains(seq, x)
   for _, value in ipairs(seq) do
      if value == x then return true end
   end
   return false
end
assert(contains(namesTest, 'factorValue'))
assert(contains(namesTest, 'numberValue'))

-- head
local df = Dataframe.newFromFile{file = testFileName}
local dfTest = df:head(2)
assert(dfTest:nRows() == 2)
assert(dfTest:nCols() == df:nCols())
--print('df'); df:print()
--print('dfTest'); dfTest:print()
for i = 1, 2 do
   assert(df:get('factorValue', i) == dfTest:get('factorValue', i))
   assert(df:get('numberValue', i) == dfTest:get('numberValue', i))
   assert(df:get('stringValue', i) == dfTest:get('stringValue', i))
end
-- all of the levels are supposed to be in the head
for k, v in pairs(df.levels) do
   assert(#v == #dfTest.levels[k])
end


-- column
local df = Dataframe.newFromFile{file = testFileName}
local values = df:column('numberValue')
assert(#values == 4)
assert(values[1] == 10)
--print('values'); print(values)
assert(values[4] == Dataframe.NA)
values = df:column('non existent column')
assert(values == nil)

-- addColumn
local df = Dataframe.newFromFile{file = testFileName}
df:addColumn('new', {1,2,3,4})
assert(df:nCols() == 4)
local values = df:column('new')
for i = 1, 4 do 
   assert(values[i] == i)
end

-- dropColumn
local df = Dataframe.newFromFile{file = testFileName}
--df:print()
df:dropColumn('factorValue')
assert(df:nCols() == 2)
assert(df:column('numberValue') ~= nil)
assert(df:column('stringValue') ~= nil)

-- newEmpty
local df = Dataframe.newEmpty()
--print('empty df'); df:print(); stop()
assert(df:nRows() == 0)
assert(df:nCols() == 0)

-- merge test 1
local df = Dataframe.newFromFile{file = testFileName}
--print('df'); df:print()
df:addColumn('Record', {1,2,3,4})
local other = Dataframe{values = {}, levels = {}}
other:addColumn('num', {10, 30, 40})
other:addColumn('Record', {1,2,3})
--print('other'); print(other)
local merged = Dataframe.newFromMerge{dfX=df, byX = 'numberValue',
                                      dfY=other, byY = 'num'}
--print('merged'); print(merged)
local function checkMerged(merged)
   assert(merged:nRows() == 2)
   assert(merged:nCols() == 6)
   local function checkCol(colName, expected1, expected2) 
      assert(merged:get(colName, 1) == expected1)
      assert(merged:get(colName, 2) == expected2)
   end
   --checkCol('x Record', 1, 3)
   --checkCol('y Record', 1, 2)
   checkCol('factorValue', 1, 1)
   checkCol('stringValue', 1, 3)
   checkCol('num', 10, 30)
   checkCol('numberValue', 10, 30)
end
checkMerged(merged)

-- try shorter one as X
local merged = Dataframe.newFromMerge{dfX=other, byX = 'num',
                                      dfY=df, byY = 'numberValue'}
--print('merged'); print(merged)
checkMerged(merged)

-- merge test 2
local dfX = Dataframe.newEmpty()
dfX:addColumn('id', {1,2,3,4,5})
dfX:addColumn('value', {"x1", "x2", "x3", "x4", "x5"})

local dfY = Dataframe.newEmpty()
dfY:addColumn('id', {1,3,6,7,8})
dfY:addColumn('value', {"y1", "y2", "y3", "y4", "y5"})

local merged = Dataframe.newFromMerge{dfX=dfX, byX='id',
                                      dfY=dfY, byY='id'}
--print('merged'); merged:print()
assert(merged:nRows() == 2)
assert(merged:nCols() == 4)
local function checkCol(df, colName, value1, value2)
   assert(value1 == df:get(colName, 1))
   assert(value2 == df:get(colName, 2))
end
checkCol(merged, 'x value', 'x1', 'x3')
checkCol(merged, 'y value', 'y1', 'y2')
checkCol(merged, 'x id', 1, 3)
checkCol(merged, 'y id', 1, 3)

-- remove test file
os.remove(testFileName)

-- split
do
   local verbose = 0
   local vp = makeVp(verbose, 'splitDf_test')
   
   torch.manualSeed(123)
   
   local table = {}
   table.obsIndex = {1,2,3,4,5,6,7,8,9,10}
   
   local df = Dataframe{values=table}
   
   local df1, df2 = df:split(0.30)
   vp(1, 'df1', df1)
   vp(1, 'df2', df2)
   assert(df1:nRows() == 2)
   assert(df1:nCols() == 1)

   assert(df2:nRows() == 8)
   assert(df2:nCols() == 1)
end

print("ok Dataframe")
