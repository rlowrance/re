-- round.lua
-- round number to given number of decimal places
-- ARGS
-- num : number
-- idp : number of decimal places; can be negative
--
-- ref: lua-users.org/wiki/SimpleRound/
function round(num, idp)
   local mult = 10 ^ (idp or 0)
   return math.floor(num * mult + 0.5) / mult
end

