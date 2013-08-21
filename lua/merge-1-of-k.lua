-- merge-1-of-k.lua
-- Merge a collection of 1-of-k files into a single csv file.

require 'CsvUtils'

--------------------------------------------------------------------------------
-- read command line, setup directories, start logging
--------------------------------------------------------------------------------

do
   local cmd = torch.CmdLine()
   cmd:text('Impute missing features in 2R using 1A')
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   cmd:option('-dataDir', '../../data/', 'Path to data directory')
   cmd:option('-feature','','Feature to merge in {"foundation"}')
   params = cmd:parse(arg)

   -- check for missing parameter
   function missing(name) error('missing parameter -' .. name) end
   if params.feature == '' then missing('feature') end

   -- setup directories
   dirObs1AFeatures = params.dataDir .. 'generated-v4/obs1A/features/'
   dirAnalysis = params.dataDir .. 'generated-v4/obs2R/analysis/'
   
   dirResults = dirAnalysis .. cmd:string('impute', params, {})

   -- start logging
   os.execute('mkdir' .. dirResults)
   cmd:log(dirResults .. '-log.txt', params)

end

--------------------------------------------------------------------------------
-- check arrays for consistency
--------------------------------------------------------------------------------

-- check that all arrays have same size
function checkSameSize(...)
   local theSize
   for i, v in ipairs{...} do
      if theSize == nil then
         theSize = #v
      else
         assert(theSize == #v, i .. ' is not of size ' .. theSize)
      end
   end
end

-- check that exactly one value is selected in each observations
function checkOnlyOne(...)
   local numObservations
   for i, v in ipairs{...} do
      numObservations = #v 
      break
   end
   local numErrors = 0
   for i=1,numObservations do
      local selected = {}
      for k, v in ipairs{...} do 
         if v[i] == 1 then 
            selected[#selected + 1] = k
         end
      end
      if #selected ~= 1 then
         numErrors = numErrors + 1
         print('error: observation', i, 'selected', selected)
      end
   end
   if numErrors > 0 then error(numErrors, 'errors found') end
end

function check(...)
   checkSameSize(...)
   checkOnlyOne(...)
end

function baseName()
   if params.feature == 'foundation'   then return 'FOUNDATION-CODE'
   elseif params.feature == 'heating'  then return 'HEATING-CODE'
   elseif params.feature == 'location' then return 'LOCATION-INFLUENCE-CODE'
   elseif params.feature == 'parking'  then return 'PARKING-TYPE-CODE'
   elseif params.feature == 'roof'     then return 'ROOF-TYPE-CODE'
   else
      error(params.feature .. ' is not programmed')
   end
end
      
function makeFileName(suffix)
   return dirObs1AFeatures .. baseName() .. '-is-' .. suffix .. '.csv'
end

function createFoundation()
   -- read into arrays
   local f1 = CsvUtils.read1Number(makeFileName('001'))
   local f2 = CsvUtils.read1Number(makeFileName('CRE'))
   local f3 = CsvUtils.read1Number(makeFileName('MSN'))
   local f4 = CsvUtils.read1Number(makeFileName('PIR'))
   local f5 = CsvUtils.read1Number(makeFileName('RAS'))
   local f6 = CsvUtils.read1Number(makeFileName('SLB'))
   local f7 = CsvUtils.read1Number(makeFileName('UCR'))
   check(f1, f2, f3, f4, f5, f6, f7)
   outFileName = baseName() .. '.csv'
   outFilePath = dirObs1AFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write('code')
   out:write('\n')
   for i=1,#f1 do
      if     f1[i] == 1 then out:write('001\n')
      elseif f2[i] == 1 then out:write('CRE\n')
      elseif f3[i] == 1 then out:write('MSN\n')
      elseif f4[i] == 1 then out:write('PIR\n')
      elseif f5[i] == 1 then out:write('RAS\n')
      elseif f6[i] == 1 then out:write('SLB\n')
      elseif f7[i] == 1 then out:write('UCR\n')
      else
         error(i .. ' has nothing selected')
      end
   end
   out:close()
end

function createHeating()
   local f1 = CsvUtils.read1Number(makeFileName('00S'))
   local f2 = CsvUtils.read1Number(makeFileName('001'))
   local f3 = CsvUtils.read1Number(makeFileName('BBE'))
   local f4 = CsvUtils.read1Number(makeFileName('CL0'))
   local f5 = CsvUtils.read1Number(makeFileName('FA0'))
   local f6 = CsvUtils.read1Number(makeFileName('FF0'))
   local f7 = CsvUtils.read1Number(makeFileName('GR0'))
   local f8 = CsvUtils.read1Number(makeFileName('HP0'))
   local f9 = CsvUtils.read1Number(makeFileName('HW0'))
   local f10 = CsvUtils.read1Number(makeFileName('RD0'))
   local f11 = CsvUtils.read1Number(makeFileName('SP0'))
   local f12 = CsvUtils.read1Number(makeFileName('ST0'))
   local f13 = CsvUtils.read1Number(makeFileName('SV0'))
   local f14 = CsvUtils.read1Number(makeFileName('WF0'))
   check(f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14)
   outFileName = baseName() .. '.csv'
   outFilePath = dirObs1AFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write('code')
   out:write('\n')
   for i=1,#f1 do
      if     f1[i] == 1  then out:write('00S\n')
      elseif f2[i] == 1  then out:write('001\n')
      elseif f3[i] == 1  then out:write('BBE\n')
      elseif f4[i] == 1  then out:write('CL0\n')
      elseif f5[i] == 1  then out:write('FA0\n')
      elseif f6[i] == 1  then out:write('FF0\n')
      elseif f7[i] == 1  then out:write('GR0\n')
      elseif f8[i] == 1  then out:write('HP0\n')
      elseif f9[i] == 1  then out:write('HW0\n')
      elseif f10[i] == 1 then out:write('RD0\n')
      elseif f11[i] == 1 then out:write('SP0\n')
      elseif f12[i] == 1 then out:write('ST0\n')
      elseif f13[i] == 1 then out:write('SV0\n')
      elseif f14[i] == 1 then out:write('WF0\n')
      else
         error(i .. ' has nothing selected')
      end
   end
   out:close()
end

function createLocation()
   local f1 = CsvUtils.read1Number(makeFileName('I01'))
   local f2 = CsvUtils.read1Number(makeFileName('IBF'))
   local f3 = CsvUtils.read1Number(makeFileName('ICA'))
   local f4 = CsvUtils.read1Number(makeFileName('ICR'))
   local f5 = CsvUtils.read1Number(makeFileName('ICU'))
   local f6 = CsvUtils.read1Number(makeFileName('IGC'))
   local f7 = CsvUtils.read1Number(makeFileName('ILP'))
   local f8 = CsvUtils.read1Number(makeFileName('IRI'))
   local f9 = CsvUtils.read1Number(makeFileName('IWL'))
   check(f1, f2, f3, f4, f5, f6, f7, f8, f9)
   outFileName = baseName() .. '.csv'
   outFilePath = dirObs1AFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write('code')
   out:write('\n')
   for i=1,#f1 do
      if     f1[i] == 1  then out:write('I01\n')
      elseif f2[i] == 1  then out:write('IBF\n')
      elseif f3[i] == 1  then out:write('ICA\n')
      elseif f4[i] == 1  then out:write('ICR\n')
      elseif f5[i] == 1  then out:write('ICU\n')
      elseif f6[i] == 1  then out:write('IGC\n')
      elseif f7[i] == 1  then out:write('ILP\n')
      elseif f8[i] == 1  then out:write('IRI\n')
      elseif f9[i] == 1  then out:write('IWL\n')
      else
         error(i .. ' has nothing selected')
      end
   end
   out:close()
end

function createParking()
   local f1  = CsvUtils.read1Number(makeFileName('110'))
   local f2  = CsvUtils.read1Number(makeFileName('120'))
   local f3  = CsvUtils.read1Number(makeFileName('140'))
   local f4  = CsvUtils.read1Number(makeFileName('450'))
   local f5  = CsvUtils.read1Number(makeFileName('920'))
   local f6  = CsvUtils.read1Number(makeFileName('A00'))
   local f7  = CsvUtils.read1Number(makeFileName('ASP'))
   local f8  = CsvUtils.read1Number(makeFileName('OSP'))
   local f9  = CsvUtils.read1Number(makeFileName('PAP'))
   local f10 = CsvUtils.read1Number(makeFileName('Z00'))
   check(f1, f2, f3, f4, f5, f6, f7, f8, f9, f10)
   outFileName = baseName() .. '.csv'
   outFilePath = dirObs1AFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write('code')
   out:write('\n')
   for i=1,#f1 do
      if     f1[i] == 1   then out:write('110\n')
      elseif f2[i] == 1   then out:write('120\n')
      elseif f3[i] == 1   then out:write('140\n')
      elseif f4[i] == 1   then out:write('450\n')
      elseif f5[i] == 1   then out:write('920\n')
      elseif f6[i] == 1   then out:write('A00\n')
      elseif f7[i] == 1   then out:write('ASP\n')
      elseif f8[i] == 1   then out:write('OSP\n')
      elseif f9[i] == 1   then out:write('PAP\n')
      elseif f10[i] == 1  then out:write('Z00\n')
      else
         error(i .. ' has nothing selected')
      end
   end
   out:close()
end

function createRoof()
   local f1  = CsvUtils.read1Number(makeFileName('F00'))
   local f2  = CsvUtils.read1Number(makeFileName('G00'))
   local f3  = CsvUtils.read1Number(makeFileName('I00'))
   check(f1, f2, f3)
   outFileName = baseName() .. '.csv'
   outFilePath = dirObs1AFeatures .. outFileName
   out = io.open(outFilePath, 'w')
   out:write('code')
   out:write('\n')
   for i=1,#f1 do
      if     f1[i] == 1   then out:write('F00\n')
      elseif f2[i] == 1   then out:write('G00\n')
      elseif f3[i] == 1   then out:write('I00\n')
      else
         error(i .. ' has nothing selected')
      end
   end
   out:close()
end


if     params.feature == 'foundation' then createFoundation()
elseif params.feature == 'heating'    then createHeating()
elseif params.feature == 'location'   then createLocation()
elseif params.feature == 'parking'    then createParking()
elseif params.feature == 'roof'       then createRoof()
else
   error(params.feature .. ' is not programmed')
end

print()
print('Wrote', outFilePath)
print('Finished')


   