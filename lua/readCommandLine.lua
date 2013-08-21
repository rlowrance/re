-- readCommandLine.lua

require 'makeVerbose'

function readCommandLine(arg, msg, optionDefaults, optionExplanations)
   -- read command line arguments, supply defaults, and return options table
   -- ARGS
   -- arg                : Lua's command line arg object
   -- msg                : string, explanation of what the program does
   -- defs               : sequence that defines the available options
   --                      {{'name', default, 'explanation'}, ...}
   -- RETURN
   -- options            : table of parameters found
   -- dirResults         : string, directory name for results
   --                      depends on program name arg[0] and non-default
   --                      non-default options
   --                      this directory is created
   -- log                : Log instance opened to dirResults/log.txt
   
   local v = makeVerbose(true, 'readCommandLine')

   -- parse the defaults out of defs
   defaults = {}
   for _, value in ipairs(defs) do
      defaults[key] = value[2]
   end

   cmd = torch.CmdLine()
   cmd:text(msg)
   cmd:text('Options')
   for _, value in ipairs(defs) do
      cmd:option('--' .. value[1], value[2], value[3])
   end


   -- parse command line
   options = cmd:parse(arg)

   -- build results directory name
   dirResults = arg[0]
   local sortedKeys = sortedKeys(options)
   for _, key in ipairs(sortedKeys) do
      if options[key] ~= defaults[key] then
         dirResults = dirResults .. ',' .. key .. '=' .. tostring(options[key])
      end
   end

   -- create the results directory (it may already exist)
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      print('results directory not created', command)
      os.exit(false) -- exit with return status EXIT_FAILURE
   end
   
   -- create log file in results directory
   local pathLogFile = dirResults .. 'log.txt'
   local log = Log(pathLogFile)
   log:log('log started on ' .. os.date())
 
   
   v('arg', arg)
   v('options', options)
   v('dirResults', dirResults)
   v('log', log)

   return options, dirResults, log
end
