-- tableFoldValues.lua
-- fold values in table
function tableFoldValues(initValue, t, fn)
   local result = initValue
   for k, v in pairs(t) do
      result = fn(result, v)
   end
   return result
end
