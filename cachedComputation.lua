-- cachedComputation.lua

require 'equalObjectValues'
require 'fileExists'
require 'torch'

-- compute a value using a precomputed result, which may take a long time to compute, so
-- save the precomputed result on disk for reuse
-- ARGS
-- data              : any type
-- param             : any type
-- filepath          : string, where the precomputed result is saved
-- fnGeneral         : function(data) -> value, version
--                     where
--                      version is the version number for the computation
--                      value == nil if data == nil
-- fnSpecific        : function(value, param) --> value2
--                     where
--                      value is the value returned by fnGeneral(data)
--                      param is an arbitrary value
-- RETURNS
-- value2            : result of the compute function applied to value and param
function cachedComputation(data, param, filepath, fnGeneral, fnSpecific)
   local vp = makeVp(0, 'cachedComputation')
   assert(type(filepath) == 'string')
   assert(type(fnGeneral) == 'function')
   assert(type(fnSpecific) == 'function')

   local format = 'binary'

   if fileExists(filepath) then
      local diskfileObject = torch.load(filepath, format)
      local value, version = fnGeneral(nil)  -- runs very quickly
      assert(value == nil)
      assert(version ~= nil)
      if version == diskfileObject.version and
         equalObjectValues(data, diskfileObject.data) then
         return fnSpecific(diskfileObject.value, param)
      end
   end

   local value, version = fnGeneral(data)
   assert(value ~= nil)
   assert(version ~= nil)
   local diskfileObject = {
      value = value,
      version = version,
      data = data,
   }
   torch.save(filepath, diskfileObject, format)
   return fnSpecific(diskfileObject.value, param)
end
