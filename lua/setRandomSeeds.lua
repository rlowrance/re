-- setRandomSeeds.lua

function setRandomSeeds(seed)
   -- set the random number generator seeds for Lua and Torch
   -- ARGS
   -- seed : optional number
   --        if supplied, used as the seed
   --        if not supplied, the seed 27 is used
   -- RETURNS nil

   local seed = seed or 27

   math.randomseed(seed)
   torch.manualSeed(seed)

   return
end
