-- startMain.lua
-- start main program

function mainStart(arg, msg, defs)
   -- parse options, create results directory, and start logging
   -- ARGS
   -- arg : table, arg object when main program started
   --       contains command line
   -- msg : string describing what the main program does
   -- def : sequence of sequences describing command line options
   --       {{'-option', defaultValue, 'explanation'}, ... }
   --       Caller must supply a -dataDir option
   -- RETURNS
   -- options    : table of option values from command line and defaults
   --              augmented with 3 variables below
   --  options.dirResult : string
   --                      path to results directory which has been created
   --  options.log       : Log object
   --  options.dirOutput : string
   --                      path to output directory

   local v = makeVerbose(false, 'parseOptions')

   v('arg', arg)
   v('msg', msg)
   v('defs', defs)

   affirm.isTable(arg, 'arg')
   affirm.isString(msg, 'msg')
   affirm.isSequence(defs, 'defs')

   local cmd = torch.CmdLine()
   cmd:text(msg)
   cmd:text('Options')
   for i,def in ipairs(defs) do
      cmd:option(def[1], def[2], def[3])
   end
   local options =  cmd:parse(arg)
 
   -- dirResults
   local cs = cmd:string(arg[0], options, {})
   local dirResults = 
      options.dataDir .. 'v5/working/' .. cs .. '/'
   print('dirResults', dirResults)

   -- create dirResults
   local command = 'mkdir ' .. dirResults .. ' -p' -- no error if exists
   if not os.execute(command) then
      print('results directory not created', command)
      os.exit(false) -- exit with return status EXIT_FAILURE
   end
   
   -- log
   local pathLogFile = dirResults .. '/log.txt'
   local log = Log(pathLogFile)
   v('options', options)
   printOptions(options, log)

   -- create dirOutput
   local dirOutput = options.dataDir .. 'v5/outputs/'

   -- augment options table with 3 variables just created
   options.dirResults = dirResults
   options.log = log
   options.dirOutput = dirOutput

   -- write to log
   log:log('log started on ' .. os.date())
   log:log('program name = ' .. arg[0])
   log:log('directory for results = ' .. dirResults)
   log:log('directory for output = ' .. dirOutput)

   -- if options.seed is defined, set the random number generator seeds
   if options.seed then
      setRandomSeeds(options.seed)
      log:log('Set random number seeds (lua and torch) to %f', options.seed)
   end

   return options
end -- startMain
