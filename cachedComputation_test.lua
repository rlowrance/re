-- cachedComputation_test.lua
-- unit test

require 'cachedComputation'
require 'fileDelete'
require 'fileExists'
require 'makeVp'

local vp = makeVp(0, 'tester')

local data = 'abc'
local param = 123
local filepath = '/tmp/cachedComputation_test.serialized'

local fnGeneralMessage = nil
local function makeFnPrecompute(data, version)
   local function fnPrecompute(data)
      if data == nil then
         fnGeneralMessage = 'invoked with nil data'
         return nil, version
      else
         fnGeneralMessage = 'invoked with non nil data'
         return 'precomputed value', version
      end
   end

   return fnPrecompute
end

local function fnSpecific(value, param)
   assert(value == 'precomputed value')
   assert(param == 123)
   return 'computed value 1'
end

-- delete the cache file if it exists
if fileExists(filepath) then
   fileDelete(filepath)
end

-- original computation
fnGeneralMessage = 'not invoked'
local value2 = cachedComputation(data, param, filepath, makeFnPrecompute(data, 1), fnSpecific)
assert(value2 == 'computed value 1')
assert(fnGeneralMessage == 'invoked with non nil data')

-- use the cached value from disk
fnGeneralMessage = 'not invoked'
local value2 = cachedComputation(data, param, filepath, makeFnPrecompute(data, 1), fnSpecific)
vp(2, 'value2', value2)
assert(value2 == 'computed value 1')
vp(2, 'fnGeneralMessage', fnGeneralMessage)
assert(fnGeneralMessage == 'invoked with nil data')

-- recompute because data changed
fnGeneralMessage = 'not invoked'
data = 'def'
local value2 = cachedComputation(data, param, filepath, makeFnPrecompute(data, 1), fnSpecific)
assert(value2 == 'computed value 1')
assert(fnGeneralMessage == 'invoked with non nil data')

-- recompute because version changed
fnGeneralMessage = 'not invoked'
local value2 = cachedComputation(data, param, filepath, makeFnPrecompute(data, 2), fnSpecific)
assert(value2 == 'computed value 1')
assert(fnGeneralMessage == 'invoked with non nil data')

print('ok cachedComputation')
