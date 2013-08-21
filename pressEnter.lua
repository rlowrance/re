-- pressEnter.lua

-- press ENTER key to continue
-- ARG:
-- msg : optional string; printed if present
-- RETURN nil
function pressEnter(msg)
   if msg ~= nil then
      print(msg)
   end
   
   print('press ENTER key to continue')
   io.stdin:read()
end