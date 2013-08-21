-- optim_makeAvgOptim.lua
-- wrapper to turn any optim function into an averaging optim function

require 'optim'   -- Koray's optim table: https://github.com/koraykv/optim

-- ARGS:
-- opfunc: function used by optimizer
-- state : table used by optimizer
-- optim : function(opfunc, w, state), the optimization function, returns
--         newW, fxs, and up to 3 optional additional parameters
-- method: string, name of method to create averages; values:
--         'exponential', use exponential decay
--         'arithmetic', use last n values
-- methodParam: number, paramater to method; value depends on method
--   if method == 'exponential', methodParam is in [0,1] and is the weight
--                               given to the last observed w values
--   if method == 'arithmetic', methodParm is a positive integer, the number of
--                          w values arithmetically averaged
--
-- RETURN
-- step: function(w), return optim(opfunc, w, state)
-- avg : function(), return average w using method and methodParam
function optim.makeAvgOptim(opfunc, state, optim, method, methodParam)
   local decayedW = nil
   local recentWs = {}
   local recentNextIndex = 0
   if method == 'exponential' then
      assert(0 <= methodParam and methodParam <= 1, 
             'methodParam not in [0,1]')
   elseif method == 'arithmetic' then
      assert(0 < methodParam and methodParam == math.floor(methodParam), 
             'methodParam not positive integer')
   else 
      error('method not known: ' .. method)
   end
   
   -- take the next step if using exponential averaging
   local function stepExponential(w)
      local newW, fxs, other1, other2, other3 = optim(opfunc, w, state)
      if decayedW == nil then
         decayedW = newW
      else
         decayedW = decayedW * (1 - methodParam) + newW * methodParam
      end
      return newW, fxs, other1, other2, other3
   end

   -- return the average w if using exponential averaging
   local function avgExponential()
      if decayedW == nil then
         error('must call step() at least once')
      end
      return decayedW
   end
   
   -- take the next step if using arithmetic averaging
   local function stepArithmetic(w)
      local newW, fxs, other1, other2, other3 = optim(opfunc, w, state)
      recentNextIndex = recentNextIndex + 1
      if recentNextIndex > methodParam then
         recentNextIndex = 1
      end
      recentWs[recentNextIndex] = newW
      return newW, fxs, other1, other2, other3
   end

   -- return the average w if using arithmetic averaging
   local function avgArithmetic()
      if recentNextIndex == 0 then
         error('must call step() at least once')
      end
      local sum = torch.Tensor(w:size(1)):zero()
      local n = #recentWs
      for i = 1, n do
         sum:add(recentWs[i])
      end
      local avg = sum / n
      return avg
   end

   -- return correct functions
   if method == 'exponential' then
      return stepExponential, avgExponential
   else
      return stepArithmetic, avgArithmetic
   end
end