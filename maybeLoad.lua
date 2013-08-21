-- maybeLoad.lua

-- load a serialized object if its file exists and the object is valid
-- ARGS:
-- pathToObject : string, path containing data written by torch.save in binary format
-- fValidate    : function(obj) returning true iff the obj is valid
-- RETURN:
-- obj or nil   : return obj only if the file exists and contains a valid object
function maybeLoad(pathToObject, fValidate)
   local f = io.open(pathToObject, 'r')
   if f == nil then
      return nil
   end
   local obj = torch.load(pathToObject)
   if obj == nil or fValidate(obj) == false then
      return nil
   else
      return obj
   end
end