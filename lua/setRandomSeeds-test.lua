-- setRandomSeeds-test.lua
-- unit test of setRandomSeeds

require 'setRandomSeeds'
require 'Tester'

test = {}
tester = Tester()

function check(seed)
   setRandomSeeds(seed)
   
   local function randomSequence(n, generator)
      -- return n random numbers from the generator
      local result = {}
      for i = 1, n do
         result[#result + 1] = generator()
      end
      return result
   end -- randomSequence

   local function randomSeqLua(n)
      -- return n random numbers in [0,1) from the Lua random num generator
      return randomSequence(n, math.random)
   end -- randomSeqLua

   local function randomSeqTorch(n)
      -- return n random 32-bit integers for the Torch random num generator
      return randomSequence(n, torch.random)
   end -- randomSeqTorch
   
   local function allEqual(seq1, seq2)
      for i = 1, #seq1 do
         if seq1[i] ~= seq2[i] then return false end
      end
      return true
   end -- allEqual

   local function assertDifferent(seq1, seq2)
      -- return true iff the sequences are different
      tester:asserteq(#seq1, #seq2)
      tester:assert(not allEqual(seq1, seq2))
   end -- assertDifferent

   local function check(generateSeq)
      local sequenceSize = 10
      local initialSequence = randomSequence(sequenceSize, generateSeq)
      local nTrials = 10
      for i = 1, nTrials do
         local anotherSequence = randomSequence(sequenceSize, generateSeq)
         assertDifferent(initialSequence, anotherSequence)
      end
   end

   check(torch.random)
   check(math.random)
end -- check

function test.explicitSeed()
   check(101)
end 

function test.implicitSeed()
   check()
end

tester:add(test)
local verbose = true
tester:run(verbose)
