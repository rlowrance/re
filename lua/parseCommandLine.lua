-- parseCommandLine.lua

require 'affirm'
require 'makeVerbose'

function parseCommandLine(arg, msg, optionDefaults, optionExplanations)
   -- parse command line arguments, supply defaults, and return options table
   -- ARGS
   -- arg                : Lua's command line arg object
   -- msg                : string, explanation of what the program does
   -- optionDefault      : table; key = option name, value = default value
   -- optionExplanations : table; key = option name, value = explanation to user
   -- RETURN
   -- options            : table of parameters found
   
   local v = makeVerbose(false, 'parseCommandLine')
   
   v('arg', arg)
   v('msg', msg)
   v('optionDefaults', optionDefaults)
   v('optionExplanations', optionExplanations)

   affirm.isTable(arg, 'arg')
   affirm.isString(msg, 'msg')
   affirm.isTable(optionDefaults, 'optionDefaults')
   affirm.isTable(optionExplanations, 'optionExplanations')

   cmd = torch.CmdLine()
   cmd:text(msg)
   cmd:text()
   cmd:text('Run from lua directory')
   cmd:text()
   cmd:text('Options')
   for name, default in pairs(optionDefaults) do
      assert(default)
      local explanation = optionExplanations[name] or ''
      cmd:option('-' .. name, default, explanation)
   end
   cmd:text()

   -- parse command line
   options = cmd:parse(arg)

   v('options', options)

   return options
end
