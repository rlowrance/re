-- splitString.lua
-- split a string into components separated by a pattern
-- ref: http://lua-users.org/wiki/SplitJoin

-- split string using pattern
-- 
-- Args:
-- str: string to split
-- divider: string (not pattern)
--
-- Returns sequence containing values between the divider string
function splitString(str, divider)
   assert(type(str) == 'string')
   local t = {}
   local lastStart = 1
   local lastEnd = 0
   local startSearch = 1
   while startSearch <= #str do
      local s, e = str:find(divider, startSearch, true)
      if s == nil then
         -- divider not found in str[startSearch:]
         -- pick up last field
         t[#t + 1] = str:sub(startSearch, #str)
         break
      else
         -- divider found in str[s:e]
         if s == startSearch then
            t[#t + 1] = ''
         else
            t[#t + 1] = str:sub(startSearch , s - 1)
         end
         startSearch = e + 1
         -- detect no last field
         if startSearch > #str then
            t[#t + 1] = ''
            break
         end
      end
   end
   return t
end

--[[ original code
function split(str, pat)
   error('original code')
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end
   ]]