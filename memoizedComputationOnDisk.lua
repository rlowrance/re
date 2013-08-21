-- memoizedComputationOnDisk.lua

require 'makeVp'
require 'maybeLoad'
require 'Timer'
require 'validateAttributes'

-- memoize a function using the Disk to save previously computed values
-- ARGS
-- pathToFile : string, should contain name of the function as a string
--              ex: moduleName .. '-' .. functionName .. '.ser'
-- version    : computation version
-- fn         : function
-- ...        : arbitary objects, the args to fn(arg1, ..., argN)
-- RETURNS
-- usedCacheValue      : boolean
-- fn(arg1, ..., argN) : one or more objects, may re-use value from disk file
function memoizedComputationOnDisk(pathToFile, version, fn, ...)
   local vp = makeVp(2, 'memoizedComputationOnDisk')
   local fnArgs = {...}
   vp(1, 'pathToFile', pathToFile, 'version', version, 'fn', fn, 'fnArgs', fnArgs)

   validateAttributes(pathToFile, 'string')
   validateAttributes(version, 'number')
   validateAttributes(fn, 'function')
   validateAttributes(fnArgs, 'table')
   assert(#fnArgs <= 7)  -- the value 7 is hard-coded in the logic below

   local function isValidObject(obj)
      local vp = makeVp(0, 'isValidObject')
      vp(1, 'obj', obj)
      local isValid =
         equalObjects(obj.version, version) and
         equalObjects(obj.fnArgs, fnArgs)
      vp(1, 'isValid', isValid)
      return isValid
   end

   local timer = Timer()
   local obj = maybeLoad(pathToFile, isValidObject)
   vp(2, 'maybe loaded obj', obj)

   -- return zero or more values
   local function returnValues(values)
      local vp = makeVp(0, 'returnValues')
      vp(1, 'values', values)

      local nValues = #values
      if nValues == 0 then
         return 
      elseif nValues == 1 then
         return values[1]
      elseif nValues == 2 then
         return values[1], values[2]
      elseif nValues == 3 then
         return values[1], values[2], values[3]
      elseif nValues == 4 then
         return values[1], values[2], values[3], values[4]
      elseif nValues == 5 then
         return values[1], values[2], values[3], values[4],
                values[5]
      elseif nValues == 6 then
         return values[1], values[2], values[3], values[4],
                values[5], values[6]
      elseif nValues == 7 then
         return values[1], values[2], values[3], values[4],
               values[5], values[6], values[7]
      else
         vp(0, 'nValues', nValues)
         error('not yet implemented')
      end
   end

   local usedCacheValue = true
   if obj ~= nil then
      vp(2, 'used result from disk; wall clock sec', timer:wallclock())
      return usedCacheValue, returnValues(obj.values)
   end

   vp(2, 'computing results from scratch')
   local timer = Timer()
   local value1, value2, value3, value4, value5, value6, value7 = fn(...)
   local values = {value1, value2, value3, value4, value5, value6, value7}

   -- would like to write the fn itself (it's address), but torch.save seems to
   -- wrap it and hence write a different function address
   local obj = {version = version,
                fnArgs = fnArgs,
                values = values}
   vp(3, 'obj to be written to file', obj)
   vp(2, 'obj.version', obj.version)
   vp(2, '#obj.fnArgs', #obj.fnArgs)
   vp(2, '#obj.values', #obj.values)
   torch.save(pathToFile, obj)
   vp(2, 'computed results from scratch; wall clock used', timer:wallclock())

   return not usedCacheValue, returnValues(obj.values)
end
      
   
   