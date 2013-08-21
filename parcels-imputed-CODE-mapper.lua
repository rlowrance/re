-- main program to filter a slice of unknown codes into a slice
-- of imputed codes
--
-- COMMAND LINE OPTIONS
-- --slice [N|all]  read specified slice of stdin or all
--                  use all if input is actually a slice
-- --of M           number of slices; use if --slice N is specified
--
-- -- code CODE     name of code (e.g., HEATING.CODE)
-- -- kmPerYear N   kilometers per year
-- -- k N           number of neighbors
-- -- lambda F      regularizer coefficient
-- 
-- INPUT FILES
-- stdin : apns and features of unknown heating codes
--         a slice or the entire file parcels-HEATING.CODE-unknown.csv
--         note: does not have a CSV header
-- parcels-CODE-unknown-fields.csv names of fields in stdin
-- parcels-CODE-known.csv apns, features, code where known
--
-- OUTPUT FILES
-- stdout : slice (apn \t kmPerYear, k, lambda, CODENAME, estCodeValue)
-- stderr : error log

require 'attributesLocationsTargetsApns'
require 'Log'
require 'NamedMatrix'
require 'parseCommandLine'
require 'validateAttributes'

-- read fields names for file with unknown names
-- ARGS:
-- logger : Log instance
-- path   : string, path to file
-- RETURNS:
-- t      : table such that t[i] == name of column i in file unknown
local function readUnknownFields(logger, path)
   local vp = makeVp(1, 'readUnkownFields')
   validateAttributes(logger, 'Log')
   validateAttributes(path, 'string')

   local f = io.open(path, 'r')
   if f == nil then error('unable to open path ' .. path) end

   local t = {}
   for line in f:lines('*l') do
      table.insert(t, line)
   end

   vp(1, 't', t)
   return t
end 

-- read known features, apns, codes
-- ARGS:
-- logger    : Log instance
-- path      : string, path to file
-- readLimit : number, -1 or number of records to read
-- code      : string, name of code field
-- RETURNS:
-- nm     : NamedMatrix
local function readKnown(logger, path, readLimit, code)
   local vp = makeVp(0, 'readUnkownFields')
   validateAttributes(logger, 'Log')
   validateAttributes(path, 'string')
   validateAttributes(readLimit, 'number', '>=', -1)
   validateAttributes(code, 'string')

   local numberColumns = {'apn.recoded',
                          'YEAR.BUILT',
                          'LAND.SQUARE.FOOTAGE',
                          'TOTAL.BATHS.CALCULATED',
                          'BEDROOMS',
                          'PARKING.SPACES',
                          'UNIVERSAL.BUILDING.SQUARE.FEET',
                          'G LATITUDE',
                          'G LONGITUDE'}
  local factorColumns = {code}
  local nm = NamedMatrix.readCsv{file=path,
                                 nRows=readLimit,
                                 numberColumns=numberColumns,
                                 factorColumns=factorColumns,
                                 nanString=''}
  vp(1, 'nm', nm)
  return nm
end 
  
-------------------------------------------------------------------------------
-- MAIN PROGRAM
-- ----------------------------------------------------------------------------


local vp = makeVp(2, 'main program')
vp(1, 'arg', arg)

local clArgs = arg
local option = {}
option.slice = parseCommandLine(clArgs, 'value', '--slice')
assert(option.slice ~= nil, '--slice [N|all] must be present')

if option.slice == 'all' then
   if parseCommandLine(clArgs, 'present', '--of') then
      error('do not supply --of when specifying --slice all')
   end
else
   option.slice = tonumber(option.slice)
   validateAttributes(option.slice, 'number', '>=', 1)
   option.of = tonumber(parseCommandLine(clArgs, 'value', '--of'))
   validateAttributes(option.of, 'number', '>=', 1)
   assert(option.slice <= option.of)
end


option.code = parseCommandLine(clArgs, 'value', '--code')
validateAttributes(option.code, 'string')

option.kmPerYear = tonumber(parseCommandLine(clArgs, 'value', '--kmPerYear'))
validateAttributes(option.kmPerYear, 'number', '>=', 0)

option.k = tonumber(parseCommandLine(clArgs, 'value', '--k'))
validateAttributes(option.k, 'number', 'integer', '>=', 2)

option.lambda = tonumber(parseCommandLine(clArgs, 'value', '--lambda'))
validateAttributes(option.lambda, 'number', '>=', 0)

-- paths to input and log files
local dirOutput = '../data/v6/output/'
local baseName = 'parcels-' .. option.code 
local pathToKnown = dirOutput .. baseName .. '-known.csv'
local pathToUnknownFields = dirOutput .. baseName .. '-unknown-fields.csv'
local optionsString = 
   '-kmPerYear-' .. tostring(option.kmPerYear) ..
   '-k' .. tostring(option.k) ..
   '-lambda' .. tostring(option.lambda)
local pathToLog = dirOutput .. baseName .. optionsString .. '.log'
vp(2, 'pathToLog', pathToLog)

-- start logging
local logger = Log(pathToLog)

-- read the input files
local parcelsFieldsUnknown = readUnknownFields(logger, pathToUnknownFields)
local readLimit = 1000
local known = readKnown(logger, pathToKnown, readLimit, option.code)
local known = attributesLocationsTargetsApns(known, option.code)

error('write more')
