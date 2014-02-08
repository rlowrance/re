-- Random.lua
-- generate Tensors with random numbers

if false then
   r = Random():integer(nSamples, lowest, highest) -- uniform integers in [lowest, highest]
   r = Random():uniform(nSamples, lowest, highest) -- uniform reals in [lowest, highest]
end

require 'assertEq'
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
-- t(x) = a e ^(bx) and then to sample x uniformly in [0,1] after
-- selection a and b s.t. t(0) = lowest and t(1) = highest.
-- MATH
-- 1. t(0) == lowest <==> a e ^ 0 = lowest <==> a == lowest
-- 2. t(1) == highest <==> a e ^ b == highest <==> e^b == highest/a
--    <==> e^b = highest/lowest <==> b = ln(highest / lowest)
function Random:geometric(nSamples, lowest, highest)
   local vp = makeVp(0, 'geometric')
   vp(1, 'nSamples', nSamples, 'lowest', lowest, 'highest', highest)
   
   assert(nSamples > 0, 'cannot have zero samples')
   assert(lowest <= highest, 'lowest exceed highest')
   assert(lowest ~= 0, 'lowest cannot be zero')

   local a = lowest
   local b = math.log(highest / lowest)
   vp(2, 'a', a, 'b', b)

   local function t(x) 
      local e = math.exp(1)
      return a * (e ^ (b * x))
   end

   assertEq(t(0), lowest,  .00001)
   assertEq(t(1), highest, .00001)

   local u = self:uniform(nSamples, 0, 1)
   local result = torch.Tensor(nSamples)
   for i = 1, nSamples do
      result[i] = t(u[i])
      vp(2, 'i', i, 'u', u[i], 'result', result[i])
   end
   vp(1, 'result', result)
   return result
end
