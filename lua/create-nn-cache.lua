-- create-nn-cache.lua
-- build cache of indices of nearest neighbors

require 'all'

--------------------------------------------------------------------------------
-- FUNCTIONS
--------------------------------------------------------------------------------

function makeNncachebuilder(trainingData, options)
   -- return instance of Nncachebuilder

   local dropRedundant = true
   local nncb = Nncachebuilder(trainingData.features, options.shards)

   return nncb
end -- makeNncachebuilder

function makeFilePathPrefix(options)
   local filePathPrefix = 
      options.dirOutput .. 
      'obs' .. options.obs .. '-'
   if options.test == 1 then
      filePathPrefix = filePathPrefix .. 'test-'
   end
   return filePathPrefix
end -- makeFilePathPrefix
   

function createShard(options)
   -- create one shard file in the output directory
   local v, isVerbose = makeVerbose(true, 'createShard')
   verify(v, isVerbose,
          {{options, 'options', 'isTable'}})

   -- read the training data
   local dropRedundant = true
   local nObservations, trainingData = readTrainingData(options,
                                                        options.log, 
                                                        not dropRedundant)
   
   local nncb = makeNncachebuilder(trainingData, options)
   local filePathPrefix = makeFilePathPrefix(options)
   local created = nncb:createShard(options.shard, filePathPrefix)
   options.log:log('created shard file %s', created)
end -- createShard


function mergeShards(options)
   -- merge the shards into one file in output directory
   local v, isVerbose = makeVerbose(true, 'createShard')
   verify(v, isVerbose,
          {{options, 'options', 'isTable'}})

   local filePathPrefix = makeFilePathPrefix(options)
   local nRecs, created = 
      Nncachebuilder.mergeShards(options.shards, filePathPrefix)
   options.log:log('created merged shard file %s', created)
   options.log:log('with %d records', nRecs)
end -- mergeShards




--------------------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------------------

print('********************************************************************')

local v = makeVerbose(true, 'main')

local options = 
   mainStart(arg, 
             'split input files into train, test files',
             {{'-dataDir', '../../data/', 'path to data directory'},
              {'-debug', 0, '0 for no debugging code'},
              {'-inputLimit', 0, 'if not 0, read this many input recs'},
              {'-merge', 0, 'if 1, then merge previous shards'},
              {'-obs', '', 'observation set'},
              {'-programName', arg[0], 'Name of program'},
              {'-seed', 27, 'random number seed'},
              {'-shard', 0, 'shard number to create'},
              {'-shards', 0, 'number of shards'},
              {'-test', 1, '0 for production, 1 to test'}})
   
-- validate options
assert(options.obs == '1A' or options.obs == '2R',
       'must specify obs set via -obs OBS')
assert(options.shards > 0,
       'must specify number of shards via -shards NSHARDS')
assert(options.test == 0 or options.test == 1,
       '-test TEST must be 0 or 1')

-- maybe throttle input
if options.test == 1 then
   options.inputLimit = 1000
end

if options.merge == 0 then
   createShard(options)
elseif options.merge == 1 then
   mergeShards(options)
else
   error('invalid -merge MERGE value')
end


mainEnd(options, log)