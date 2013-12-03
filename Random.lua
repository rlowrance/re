-- Random.lua
-- generate Tensors with random numbers

if false then
   r = Random():Integer(nSamples, lowest, highest) -- uniform in [lowest, highest]
   r = Random():Uniform(nSamples, lowest, highest) -- reals
end

require 'round'
require 'torch'

torch.class('Random')

function Random:__init()
end

-- return 1D Tensor of uniform random numbers in specified range
-- ARGS
-- nSamples : size of result
-- lowest   : number, each number is in the range [lowest, highest]
-- highest  : number
function Random:uniform(nSamples, lowest, highest)
   assert(nSamples > 0)
   assert(lowest <= highest)

   local result = torch.Tensor(nSamples)

   local function setOneElement(x)
      return torch.uniform(lowest, highest)
   end

   result:apply(setOneElement)

   return result
end

-- return 1D Tensor of uniform random integers in specified range
-- ARGS
-- nSamples : size of result
-- lowest   : number, each number is in the range [lowest, highest]
-- highest  : number
function Random:integer(nSamples, lowest, highest)
   assert(nSamples > 0)
   assert(lowest <= highest)

   local result = torch.Tensor(nSamples)

   local function setOneElement(x)
      return math.random(lowest, highest)
   end

   result:apply(setOneElement)

   return result
end



