-- transactions-subset1-imputed-CONDITION-CODE.lua

require 'imputeMissingFeature'

torch.manualSeed(123)   -- set for reproducability

-- parse and (for now) ignore the command line
local cmd = torch.CmdLine()
local params = cmd:parse(arg)

-- impute the missing feature
imputeMissingFeature{clArgs=arg
                     ,executableName=arg[0]
                     ,readLimit=-1
                     ,verbose=2
                     ,targetFeatureName='CONDITION.CODE'
                     ,cmd=cmd
                    }
stop()

-- OLD CODE BELOW ME
params.testing = true
params.targetFeatureName = 'CONDITION.CODE'
params.dirOutput = '../data/v6/output/'
params.pathToGeocodings = '../data/raw/geocoding.tsv'
params.pathToParcels = params.dirOutput .. 'parcels-sfr.csv'
params.readlimit = 1000
local s = split(arg[0], '.')
params.executableBase = s[1]
params.executableSuffix = s[2]
params.logfilepath = 
   params.dirOutput .. 
   params.executableBase ..
   '-' ..
   params.executableSuffix ..
   '-log.txt'
cmd:log(params.logfilepath, params)

                          
                            
                   


-- Leek's idea: simulate the method on data I know will work for log regression