-- parseOptions-test.lua
-- unit test of ParseOptions

require 'check'
require 'makeVerbose'
require 'parseOptions'
require 'Tester'

test = {}
tester = Tester()

local function append(seq, a, b)
   seq[#seq + 1] = a
   seq[#seq + 1] = b
end

function test.one()
   local v = makeVerbose(false, 'test.one')
   
   -- append some pseudo command line args to the arg from Lua
   v('arg on entry', arg)
   append(arg, '-number', '123')
   append(arg, '-string', 'abc')
  -- append(arg, '-boolean', 'true')  the underlying CmdLine doesn't handle bool
   v('arg as modified', arg)

   local options, dirResults, log, dirOutput =
      parseOptions(arg,
                   'test parseOptions',
                   {{'-dataDir', '../../data/', 'where data are'},
                    {'-number', 0, 'a number'},
                    {'-string', '', 'a string'},
                    {'-numberDefault', 0},
                    {'-stringDefault', ''}
                    
                   })

   -- check options
   v('options', options)
   tester:assert(options ~= nil)
   tester:asserteq('../../data/', options.dataDir)
   tester:asserteq(123, options.number)
   tester:asserteq('abc', options.string)
   tester:asserteq(0, options.numberDefault)
   tester:asserteq('', options.stringDefault)

   -- check dirResults
   v('dirResults', dirResults)

   local function m(s, pattern)
      local match = string.match(s, pattern)
      v('pattern', pattern)
      v('match', match)
      return match
   end

   tester:assert(nil ~= m(dirResults, 'v5/working/'))
   tester:assert(nil ~= m(dirResults, 'parseOptions%-test'))
   tester:assert(nil ~= m(dirResults, 'number=123'))
   tester:assert(nil ~= m(dirResults, 'string=abc'))

   tester:asserteq('/', string.sub(dirResults, #dirResults)) -- ends in '/'
   
   -- check log
   tester:assert(check.isTable(log))
   
   -- check dirOutput
   v('dirOutput', dirOutput)
   tester:assert(nil ~= m(dirOutput, 'v5/outputs/'))
end

tester:add(test)
tester:run(true)  -- true ==> verbose