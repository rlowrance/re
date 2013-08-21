-- extract.lua

-- extract value from varargs seq or use provided default
-- ARGS:
-- varargs      : seq
-- name         : string, name of the optional argument in the varargs list
-- defaultValue : obj, returned if requested name is not present
-- RETURNS
-- value        : the value found or, if its not present, the default value
function extract(varargs, name, defaultValue)
   assert(type(varargs) == 'table')
   assert(type(name) == 'string')

   assert((#varargs) % 2 == 0, 'not an even number of varargs')

   for i = 1, #varargs, 2 do
      local nameValue = varargs[ i]
      if nameValue == name then
         return varargs[i + 1]
      end
   end

   return defaultValue
end