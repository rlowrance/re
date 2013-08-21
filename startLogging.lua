-- startLogging.lua

-- setup logger and log the arguments. Redefine print so that it also
-- writes to a log file
-- ARGS
-- logFilePath : string, path to log file
-- clArgs      : table, sequence of arguments from the command line
-- RETURNS: nil
function startLogging(logFilePath, clArgs)
   local vp = makeVp(1, 'startLogging')
   vp(1, 'logFilePath', logFilePath, 'clArgs', clArgs)
   assert(type(logFilePath) == 'string')
   assert(type(clArgs) == 'table')

   -- arrange for print() to also write to the specified log file
   local cmd = torch.CmdLine()
   cmd:log(logFilePath, clArgs)

   -- write the command line args to the log file
   for i, v in ipairs(arg) do
      vp(0, 'arg[' .. i .. ']', v)
   end
   
   return nil
end