-- Random.lua
-- generate Tensors with random numbers

if false then
   r = Random():integer(nSamples, lowest, highest) -- uniform integers in [lowest, highest]
   r = Random():uniform(nSamples, lowest, highest) -- uniform reals in [lowest, highest]
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

-- return 1D Tensor of geometrically selected numbers in specified range
-- ARGS
-- nSamples : size of result
-- lowest   : number, each number is in the range [lowest, highest]
-- highest  : number
-- NOTE: The selection procedure suggested by Yann is to define
-- t(x) = a b^x and then to sample uniformly in [0,1] after
-- selection a and b s.t. a b^0 = lowest and a b^1 = highest.
-- MATH
-- Since lowest = a b^0 = a and highest = a b^1 = a b, we have
-- a = lowest
-- b = highest /a = highest / lowest
-- Then t(x) = a b ^x = lowest (highest / lowest) ^ x
function Random:geometric(nSamples, lowest, highest)
   local vp = makeVp(0, 'geometric')
   
   assert(nSamples > 0)
   assert(lowest <= highest)
   assert(lowest ~= 0)

   local a = lowest
   local b = highest / lowest
   vp(2, 'a', a, 'b', b)

   local function t(x) 
      return a * (b ^ x)
   end
   assert(t(0) == lowest)
   assert(t(1) == highest)
   

   local u = self:uniform(nSamples, 0, 1)
   local result = torch.Tensor(nSamples)
   for i = 1, nSamples do
      result[i] = t(u[i])
      vp(2, 'i', i, 'u', u[i], 'result', result[i])
   end
   vp(1, 'result', result)
   return result
end
