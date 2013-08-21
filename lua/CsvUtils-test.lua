-- CsvUtils-test.lua
-- unit tests for CsvUtils

require 'CsvUtils'

tester = torch.Tester()

tests = {}

function tests.readNumbers()
   local trace = false

   -- test return all of an array
   local hasHeader = true
   local returnKind = 'array'
   local inputLimit = 0       -- read them all
   local values, header = CsvUtils():readNumbers("CsvUtils-test-file1.csv",
                                                 hasHeader,
                                                 returnKind,
                                                 inputLimit)
   
   local function checkHeader()
      tester:asserteq(header, 'a,b,c,d', 'header')
   end

   if trace then
      print()
      print('values', values)
      print('header', header)
   end

   local function checkRecord(recordNumber, values)
      if recordNumber == 1 then
         tester:asserteq(values[1][1], 1, '1 1')
         tester:asserteq(values[1][2], 2.3, '1 2')
         tester:asserteq(values[1][3], 0.7, '1 3')
         tester:asserteq(values[1][4], 0, '1 4')
      elseif recordNumber == 2 then
         tester:asserteq(values[2][1], -4567, '2 1')
         tester:asserteq(values[2][2], -923.001, '2 2')
         tester:asserteq(values[2][3], 0, '2 3')
         tester:asserteq(values[2][4], 0, '2 4')
      else
         error('bad recordNumber=' .. recordNumber)
      end
   end

   tester:asserteq('table', type(values), 'type(values)')
   tester:asserteq(2, #values, '2 rows')
   checkHeader()
   checkRecord(1, values)
   checkRecord(2, values)

   -- read again, this time returning truncated tensor
   hasHeader = true
   returnKind = '2D Tensor'
   inputLimit = 1       -- read them all
   values, header = CsvUtils():readNumbers("CsvUtils-test-file1.csv",
                                           hasHeader,
                                           returnKind,
                                           inputLimit)
   if trace then 
      print('values', values)
   end
   tester:asserteq('torch.DoubleTensor', torch.typename(values), 'typename')
   tester:asserteq(2, values:dim(), '2D')
   tester:asserteq(1, values:size(1), '1 row')
   tester:asserteq(4, values:size(2), '4 columns')
   checkHeader()
   checkRecord(1, values)
end

function tests.read1Number()
   local trace = false

   -- test return all of an array
   local filename = "CsvUtils-test-file2.csv"
   local hasHeader = true
   local returnKind = 'array'
   local inputLimit = 0       -- read them all
   local values, header = CsvUtils():read1Number(filename,
                                                 hasHeader,
                                                 returnKind,
                                                 inputLimit)
   
   local function checkHeader()
      tester:asserteq(header, 'a', 'header')
   end

   if trace then
      print()
      print('values', values)
      print('header', header)
   end

   local function checkRecord(recordNumber, values)
      if recordNumber == 1 then
         tester:asserteq(values[1], 1, '1 1')
      elseif recordNumber == 2 then
         tester:asserteq(values[2], -4567, '2 1')
      else
         error('bad recordNumber=' .. recordNumber)
      end
   end

   tester:asserteq('table', type(values), 'type(values)')
   checkHeader()
   checkRecord(1, values)
   checkRecord(2, values)

   -- read again, this time returning truncated tensor
   hasHeader = true
   returnKind = '1D Tensor'
   inputLimit = 1       -- read just first data record
   values, header = CsvUtils():read1Number(filename,
                                           hasHeader,
                                           returnKind,
                                           inputLimit)
   if trace then
      print('values', values)
   end

   tester:asserteq('torch.DoubleTensor', torch.typename(values), 
                   'typename=' .. torch.typename(values))
   tester:asserteq(1, values:dim(), '1D')
   tester:asserteq(1, values:size(1), 'one row')
   checkHeader()
   tester:asserteq(1, values[1], 'only entry is 1')
end

if false then
   --tester:add(tests.readNumbers, 'tests.readNumbers')
   tester:add(tests.read1Number, 'test.read1Number')
else
   tester:add(tests)
end
tester:run()
