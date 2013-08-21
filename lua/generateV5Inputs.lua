-- generateV5Inputs.lua
-- read data/generated-v4/features
-- generate v5 features from them

require 'all'

--------------------------------------------------------------------------------
-- FUNCTIONS
--------------------------------------------------------------------------------

function columnSet(result, index, t)
   -- set column index of result to t
   v = makeVerbose(false, 'columnSet')
   v('result:size()', result:size())
   v('index', index)
   v('t', t)
   assert(index <= result:size(1))
   assert(result:size(1) == t:size(1))
   for i = 1, result:size(1) do
      local x = t[i]
      local y = result[index]
      v('y', y)
      v('i', i)
      result[i][index] = t[i]
   end
end -- columnSet

function copyFeatureFiles(obs, options, log, v4Dir, v5Dir)
   -- copy files from v4 to v5
   local function moveFile(fromName, toName)
      local from = v4Dir .. 'obs' .. obs .. '/features/' .. fromName .. '.csv'
      local to = v5Dir .. 'inputs/obs' .. obs .. '-all-' .. toName .. '.csv'
      local command = 'cp ' .. from .. ' ' .. to
      log:log('command: %s', command)
      local ok, s, n = os.execute(command)
      if not ok then
         print('exit status', s)
         print('signal', n)
         error('os.execute failed')
      end
   end -- moveFile

   moveFile('apns', 'apns')
   moveFile('date', 'dates')
   moveFile('day', 'days')
   moveFile('day-std', 'days-std')
   moveFile('SALE-AMOUNT', 'prices')
   log:log('copied files from v4 to v5')
end -- copyFeatureFiles

function copyHpi(options, log, v5Dir)
   local from = options.dataDir .. 'laufer-2012-03-hpi-values/hpivalues.txt'
   local to = v5Dir .. 'inputs/hpivalues.csv'
      local command = 'cp ' .. from .. ' ' .. to
      log:log('command: %s', command)
      local ok, s, n = os.execute(command)
      if not ok then
         print('exit status', s)
         print('signal', n)
         error('os.execute failed')
      end
end -- copyHpi

function generateFeatures(obs, seq, options, log, v4Dir, v5Dir)
   -- generate data/v5/inputs/features.csv
   local v = makeVerbose(true, 'generateFeatures')
   v('obs', obs)
   v('options', options)

   local nDims = #seq
   local nObs = options.nObs1A
   if obs == '2R' then 
      nObs = options.nObs2R 
   end
   if options.test == 1 then
      nObs = 1000
   end
   log:log('expecting %d observations in %s', nObs, obs)

   -- read all the feature files 
   -- build up a 2D tensor with the result
   local cu = CsvUtils()
   local result = torch.Tensor(nObs, nDims)
   local headers = {}
   for colIndex = 1, nDims do
      local inFilePath = 
         v4Dir .. 
         'obs' .. 
         obs .. 
         '/features/' .. 
         seq[colIndex] .. 
         '.csv'
      local hasHeader = true
      local returnKind = '1D Tensor'
      local inputLimit = 0
      if options.test == 1 then
         inputLimit = 1000
      end
      local t, header = cu:read1Number(inFilePath,
                                       hasHeader,
                                       returnKind,
                                       inputLimit)
      log:log('%s has %d observations', seq[colIndex], t:size(1))
      --v('header', header)
      if options.test == 0 then
         assert(t:size(1) == nObs)
      end
      columnSet(result, colIndex, t)
      headers[#headers + 1] = header
   end

   -- write the 2D tensor
   local outPath = v5Dir .. 'inputs/obs' .. obs .. '-all-features.csv'
   log:log('output path = %s', outPath)
   out = io.open(outPath, 'w')
   
   -- write the header
   local first = true
   for _, colName in ipairs(headers) do
      if not first then
         out:write(',')
      end
      out:write(colName)
      first = false
   end
   out:write('\n')

   -- write each row
   for rowIndex = 1, nObs do
      local first = true
      for colIndex = 1, nDims do
         if not first then
            out:write(',')
         end
         out:write(string.format('%f', result[rowIndex][colIndex]))
         first = false
      end
      out:write('\n')
   end
   out:close()
   log:log('wrote %d data records and the header', nObs)
   log:log('each with %d dimensions', nDims)
end -- generateFeatures


--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

print('***********************************************************************')

local v = makeVerbose(true, 'main')

local debug = 0  -- set to positive int for debugging

local options, dirResults, log, dirOut =
   parseOptions(arg,
                'copy v4 input files to v5/inputs',
                {{'-dataDir', '../../data/', 'path to data directory'},
                 {'-debug', 0, '0 for no debugging code'},
                 {'-nObs1A', 217376, 'obs set 1A size'},
                 {'-nObs2R', 1513786, 'obs set 2R size'},
                 {'-only', '', 'do only 1 obs set {1A, 2R}'},
                 {'-programName', 'generateV5Inputs', 'Name of program'},
                 {'-test', 1, '0 for production, 1 to test'}})

if debug ~= 0 then
   options.debug = debug
end

if options.debug ~= 0 then
   log:log('DEBUGGING: TOSS RESULTS')
end

if options.only ~= '' then
   options.test = 1
end

if options.test == 1 then
   log:log('TESTING: TOSS RESULTS')
end

v4Dir = options.dataDir .. 'generated-v4/'
v5Dir = options.dataDir .. 'v5/'

if options.only == '' or options.only == '1A' then
   generateFeatures('1A',
                    {'ACRES-log-std',
                     'BEDROOMS-std',
                     'census-avg-commute-std',
                     'census-income-log-std',
                     'census-ownership-std',
                     'day-std',
                     'FOUNDATION-CODE-is-001',
                     'FOUNDATION-CODE-is-CRE',
                     'FOUNDATION-CODE-is-MSN',
                     'FOUNDATION-CODE-is-PIR',
                     'FOUNDATION-CODE-is-RAS',
                     'FOUNDATION-CODE-is-SLB',
                     'FOUNDATION-CODE-is-UCR',
                     'HEATING-CODE-is-00S',
                     'HEATING-CODE-is-001',
                     'HEATING-CODE-is-BBE',
                     'HEATING-CODE-is-CL0',
                     'HEATING-CODE-is-FA0',
                     'HEATING-CODE-is-FF0',
                     'HEATING-CODE-is-GR0',
                     'HEATING-CODE-is-HP0',
                     'HEATING-CODE-is-HW0',
                     'HEATING-CODE-is-RD0',
                     'HEATING-CODE-is-SP0',
                     'HEATING-CODE-is-ST0',
                     'HEATING-CODE-is-SV0',
                     'HEATING-CODE-is-WF0',
                     'IMPROVEMENT-VALUE-CALCULATED-log-std',
                     'LAND-VALUE-CALCULATED-log-std',
                     'latitude-std',
                     'LIVING-SQUARE-FEET-log-std',
                     'LOCATION-INFLUENCE-CODE-is-I01',
                     'LOCATION-INFLUENCE-CODE-is-IBF',
                     'LOCATION-INFLUENCE-CODE-is-ICA',
                     'LOCATION-INFLUENCE-CODE-is-ICR',
                     'LOCATION-INFLUENCE-CODE-is-ICU',
                     'LOCATION-INFLUENCE-CODE-is-IGC',
                     'LOCATION-INFLUENCE-CODE-is-ILP',
                     'LOCATION-INFLUENCE-CODE-is-IRI',
                     'LOCATION-INFLUENCE-CODE-is-IWL',
                     'longitude-std',
                     'PARKING-SPACES-std',
                     'PARKING-TYPE-CODE-is-110',
                     'PARKING-TYPE-CODE-is-120',
                     'PARKING-TYPE-CODE-is-140',
                     'PARKING-TYPE-CODE-is-450',
                     'PARKING-TYPE-CODE-is-920',
                     'PARKING-TYPE-CODE-is-A00',
                     'PARKING-TYPE-CODE-is-ASP',
                     'PARKING-TYPE-CODE-is-OSP',
                     'PARKING-TYPE-CODE-is-PAP',
                     'PARKING-TYPE-CODE-is-Z00',
                     'percent-improvement-value-std',
                     'POOL-FLAG-is-0',
                     'POOL-FLAG-is-1',
                     'ROOF-TYPE-CODE-is-F00',
                     'ROOF-TYPE-CODE-is-G00',
                     'ROOF-TYPE-CODE-is-I00',
                     'SALE-AMOUNT-log-std',
                     'TOTAL-BATHS-CALCULATED-std',
                     'TRANSACTION-TYPE-CODE-is-1',
                     'TRANSACTION-TYPE-CODE-is-3',
                     'YEAR-BUILT-std'},
                    options,
                    log,
                    v4Dir,
                    v5Dir)

   copyFeatureFiles('1A',
                    options,
                    log,
                    v4Dir,
                    v5Dir)
end

if options.only == '' or options.only == '2R' then
   generateFeatures('2R',
                    {'ACRES-log-std',
                     'BEDROOMS-std',
                     'census-avg-commute-std',
                     'census-income-log-std',
                     'census-ownership-std',
                     'day-std',
                     'IMPROVEMENT-VALUE-CALCULATED-log-std',
                     'LAND-VALUE-CALCULATED-log-std',
                     'latitude-std',
                     'LIVING-SQUARE-FEET-log-std',
                     'longitude-std',
                     'PARKING-SPACES-std',
                     'percent-improvement-value-std',
                     'POOL-FLAG-is-0',
                     'POOL-FLAG-is-1',
                     'SALE-AMOUNT-log-std',
                     'TOTAL-BATHS-CALCULATED-std',
                     'TRANSACTION-TYPE-CODE-is-1',
                     'TRANSACTION-TYPE-CODE-is-3',
                     'YEAR-BUILT-std'},
                    options,
                    log,
                    v4Dir,
                    v5Dir)

   copyFeatureFiles('2R',
                    options,
                    log, 
                    v4Dir, 
                    v5Dir)
end

if options.only == '' or options.only == 'hpi' then
   copyHpi(options, log, v5Dir)
end


printOptions(options, log)

if options.test == 1 then
   log:log('TESTING')
end

if options.debug > 0 then
   log:log('DEBUGGING')
end

log:log('consider comiting the code')
log:log('ran to normal completion')
