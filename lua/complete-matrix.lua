-- complete-matrix2.lua
-- read estimates of transactions, determine sparse error matrix, and
-- complete matrix for all time periods and APNs

-- Input files:
-- FEATURES/apns.csv
-- FEATURES/dates.csv
-- FEATURES/SALE-AMOUNT-log.csv
-- ANALYSIS/create-estimates-lua-...-which=mc/estimates-mc.csv

-- Output files:
-- ANALYSIS/RESULTS/all-estimates-mc.csv
-- ANALYSIS/RESULTS/log.txt



require 'CompleteMatrix'


--------------------------------------------------------------------------------
-- readCommandLine: parse and validate command line
--------------------------------------------------------------------------------

-- ARGS
-- arg                : Lua's command line arg object
-- optionDefault      : table;key = option name, value = default value
-- optionExplanations : table; key = option name, value = explanation to user
-- RETURN
-- cmd object used to parse the args
-- options: table of parameters found
function readCommandLine(arg, optionDefaults, optionExplanations)
   local trace = true

   cmd = torch.CmdLine()
   cmd:text('Complete matrix of errors for given rank' ..
            ' for one algorithm, obs set, and radius')
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

   if trace then
      print('readCommandLine arg') print(arg)
      print('readCommandLine parsed options') print(options)
   end

   return options
end

--------------------------------------------------------------------------------
-- main program
--------------------------------------------------------------------------------

local completeMatrix = CompleteMatrix()

local options = readCommandLine(arg,
                                completeMatrix:getOptionDefaults(),
                                completeMatrix:getOptionExplanations())

completeMatrix:worker(options,
                      'complete-matrix.lua')






