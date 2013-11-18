-- stop.lua
-- stop program and print some debugging info
-- ARGS:
-- message : optional string, printed before program is halted
-- RETURNS : DOES NOT RETURN
function stop(message)
   local vp = makeVp(0, 'stop')
   vp(1, 'message', message)

   if message then
      print('about to stop: ' .. tostring(message))
   else
      print('about to stop')
   end

   -- print info about the calling function
   local info = debug.getinfo(2)
   vp(2, 'info', info)
   if info then
      print('info about the function that called stop():')
      for k,v in pairs(info) do
         print(string.format('%16s : %s', k, tostring(v)))
      end
   end

   os.exit(false)  -- exit; set OS return status to EXIT_FAILURE
end
