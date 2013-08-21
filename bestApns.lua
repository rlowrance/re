-- bestApns.lua

-- return seq of best APN values
--
-- ARGS: a table with these keys
--
-- apnsFormatted: sequence of strings, each a formatted APNs, 
-- possibly containing NA values
--
-- apnsUnformatted: sequence of strings, each an unformatted APNs, 
-- possibly containing NA values
--
-- NA: non-string object, the value that represents "not available"
--
-- Returns: seq of best APNs over {number, na}, defined by
-- 1. If unformatted APN is all digits, the use the unformatted APN.
-- 2. Remove hyphens from formatted APN.
-- 3. If the resulting string is all digits, use it.
-- 4. Otherwise the value is NA
function bestApns(t)
   local arg = {}
   arg.formatted = t.formattedApns or error('missing arg formattedApns')
   arg.unformatted = t.unformattedApns or error('missing arg unformattedApns')
   arg.na = t.na or error('missing arg na')

   assert(#arg.formatted == #arg.unformatted,
          'different number of formatted and unformatted APNs')

   local function vp(s) 
      if false then 
         print(s) 
      end 
   end

   local result = {}
   for i, value in ipairs(arg.unformatted) do
      -- accept leading and trailing spaces and a sign
      local number = tonumber(value)
      if number then
         result[#result + 1] = number
      else
         local formatted = arg.formatted[i]
         vp('formatted'); vp(formatted)
         if formatted == arg.na then
            result[#result + 1] = arg.na
         else
            -- remove hyphens and drop the second returned value from gsub
            local value = formatted:gsub('%-', '')
            number = tonumber(value)
            if number then
               result[#result + 1] = number
            else
               result[#result + 1] = arg.na
            end
         end
      end
   end

   return result
end