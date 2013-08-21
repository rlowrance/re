-- KernelSmoother.lua
-- estimate real-valued function using its noisy observations without a
-- parametric model

if false then 
   --  API summary
   ks = KernelSmoother(inputs, targets)

   -- k nearest neighbors
   estimates = ks:smoothNearestNeighbors(k, 
                                         distanceFunction, 
                                         makeNNIndices)  -- optional
   estimate = ks:estimateNearestNeighbors(query, 
                                          k, 
                                          distanceFunction, 
                                          nnIndicesFunction) -- optional

   -- Nadaraya-Watson kernel-weighted average
   estimates = ks:smoothKernelAverage(kernel)
   estimate = ks:estimateKernelAverage(query, kernel)

   -- Local Linear Regression
   estimates = ks:smoothLocalLinearRegression(kernel)
   estimate = ks:estimateLocalLinearRegression(query, kernel)

-- where

-- + distanceFunction  : function(Tensor1, Tensor2)--> number
--                     : distance from x1 to x2
-- + estimate          : number
-- + estimates         : array of numbers, parallel to targets
-- + inputs            : array of Tensors
-- + k                 : number > 0, the number of neighbors
-- + kernel            : function(Tensor1, Tensor2)--> number
--                     : closure that has captured any kernel
--                     : parameters such as a kernel radius
-- + nnIndicesFunction : optional function(query, k, distanceFunction, input)-->
--                     : array of indices, those of the k nearest neighbors
--                     : using the supplied distance function
--                     : If supplied, then distanceFunction is not used
-- + query             : Tensor
-- + targets           : array of numbers

end -- API summary

require 'Distance'
require 'Validations'

local KernelSmoother = torch.class('KernelSmoother')

function KernelSmoother:__init(inputs, targets)
   Validations.isTable(inputs, 'inputs')
   Validations.isTable(targets, 'targets')

   -- check element types in inputs and targets
   for _, input in pairs(inputs) do
      Validations.isTensor1D(input, 'element of inputs')
      self.nDimensions = input:size(1)
      break
   end
   for _, target in pairs(targets) do
      Validations.isNumber(target, 'element of targets')
      break
   end
   
   Validations.isEqual(#inputs,#targets,
                       'number of inputs', 'number of targets')
   
   self.inputs = inputs
   self.targets = targets
end

--------------------------------------------------------------------------------
-- k nearest neighbors
--------------------------------------------------------------------------------

-- estimate target value for each input
-- + k                 : number of neighbors
-- + distanceFunction  : distance between two observations
-- + nnIndicesFunction : optional function to return k nearest neighbors
function KernelSmoother:smoothNearestNeighbors(k, 
                                               distanceFunction, 
                                               nnIndicesFunction)
   Validations.isNumberGt0(k, 'k')
   Validations.isFunction(distanceFunction, 'distanceFunction')
   Validations.isNilOrFunction(nnIndicesFunction, 'nnIndicesFunction')
   
   local estimates = {}
   for i, x in pairs(self.inputs) do
      local estimate = self:estimateNearestNeighbors(i,  -- was x
                                                     k, 
                                                     distanceFunction,
                                                     nnIndicesFunction)
      estimates[#estimates + 1] = estimate
   end
   return estimates
end

-- sort pairs by distance component, the 1st component
local function aComesBeforeB(a, b)
   return a[1] < b[1]
end
   

-- return array of indices of k nearest neighbors
-- error only if there are fewer than k elements in inputs
local function defaultNnIndicesFunction(query, k, distanceFunction, inputs)
   local timing = false
   local timer = nil
   if timing then timer = torch.Timer() end
   Validations.isTensor(query, 'query')
   Validations.isNumberLe(k, #inputs, 'k', 'number of inputs')
   Validations.isFunction(distanceFunction, 'distanceFunction')
   Validations.isTable(inputs, 'inputs')

   -- determine distance-index pairs from query to each element of training set
   local distances = {}
   local timerDistances
   if timing then
      assert(217376 == #inputs, #inputs)
 
     -- don't use ipairs to iterate
      timer:reset()
      distances = {}
      for i=1,217376 do
         distances[#distances + 1] ={distanceFunction(query, inputs[i]), i}
      end
      print('user sec distances 1,217376 df', timer:time().user)
 
      -- avoid calling the intermediate function that allows flexibility
      timer:reset()
      distances = {}
      for i=1,#inputs do
         distances[#distances + 1] = {torch.dist(query, inputs[i]), i}
      end
      print('user sec distances 1,#inputs dist', timer:time().user)

      -- time for empty loop and extending the distances
      -- this is slightly faster than not extending
      timer:reset()
      for i=1,#inputs do
         distances[#distances + 1] = {nil, i}
      end
      local timeExtendDistances = timer:time().user
      print('user sec just loop extend distances', timeExtendDistances)
      timer:reset()

      -- don't extend the distances object
      distances = {}
      for i=1,#inputs do
         distances[i] = {nil, i}
      end
      local timeNoExtendDistances = timer:time().user
      print('user sec no extend distances', timeNoExtendDistances)

      -- keep track of the two approaches to distances
      timeTotalExtend = (timeTotalExtend or 0) + timeExtendDistances
      timeTotalNoExtend = (timeTotalNoExtend or 0) + timeNoExtendDistances
      print('timeTotalExtend', timeTotalExtend)
      print('timeTotalNoExtend', timeTotalNoExtend)

      -- this is the current version
      timer:reset()
      distances = {}
      for i, x in ipairs(inputs) do
         distances[#distances + 1] = {distanceFunction(query, x), i}
      end
      timerDistances = timer:time().user; 
      timer:reset()
      print('current distance time         ', timerDistances)
   end

   -- implement the fastest approach to finding the distances array
   distances = {}
   for i=1,#inputs do
      distances[#distances + 1] = {torch.dist(query, inputs[i]),i}
   end
      
   
   table.sort(distances, aComesBeforeB)
   local timerSort
   if timing then timerSort = timer:time().user; timer:reset() end

   -- return first k entries, which are the k closest
   local result = {}
   for i=1,k do
      result[#result + 1] = distances[i][2]
      --print('defaultNnIndicesFunction nextIndex', distances[i][2])
   end
   local timerResult
   if timing then timerResult = timer:time().user; timer:reset() end

   if timing then
      print('defaultNnIndicesFunction distance,sort,result,#inputs',
            timerDistances, timerSort, timerResult, #inputs)
      if false then print('timerDistances', timerDistances)
         print('timerSort', timerSort)
         print('timerResult', timerResult)
         print('k', k)
      end
   end
   return result
end

-- estimate target value for one query 
-- query             : index in input (if number) or tensor
-- k                 : number of neighbors to consider
-- distanceFunction  : compute distance between query and another observations
-- nnIndicesFunction : optional, determine k nearest neighbor indices in input
function KernelSmoother:estimateNearestNeighbors(query, 
                                                 k, 
                                                 distanceFunction, 
                                                 nnIndicesFunction)
   local timing = true
   local timer = nil
   if timing then
      timer = torch.Timer()
   end
   local trace = false
   Validations.isNumberOrTensor(query, 'query')
   Validations.isNumberLe(k, #self.inputs, 'k', 'number of inputs')
   Validations.isFunction(distanceFunction, 'distanceFunction')
   Validations.isNilOrFunction(nnIndicesFunction, 'nnIndicesFunction')
   if trace then 
      print('estimateNearestNeighbors nnIndicesFunction', nnIndicesFunction)
   end
   local nnIndicesFunction = nnIndicesFunction or defaultNnIndicesFunction
   if trace then
      print('estimateNearestNeighbors nnIndicesFunction', nnIndicesFunction)
   end

   -- determine indices of the k nearest neighbors in inputs
   local nnIndices = nnIndicesFunction(query, k, distanceFunction, self.inputs)
   -- if nnIndices is nil then the nnIndicesFunction could not determine
   -- the nearest neighbors. If so, call defaultMakeNnIndices which errors only
   -- if there are not at least k nearest neighbors
   if nnIndices == nil then 
      nnIndices = nnIndicesFunction(query, k, distanceFunction, self.inputs) 
   end
   local timeNnIndices
   if timing then 
      timeNnIndices = timer:time().user
   end
   
   -- determine average of k nearest targets

   local sumTargetValues = 0
   for i=1,k do
      if trace then 
         print('estimateNearestNeighbors index, target',
               nnIndices[i],
               self.targets[nnIndices[i]])
      end
      sumTargetValues = sumTargetValues + self.targets[nnIndices[i]]
   end
   local result = sumTargetValues / k
   if trace then
      print('estimateNearestNeighbors result', result)
   end
   if timing then
      print('estimateNearestNeighbors indices,total user secs',
            timeNnIndices, timer:time().user)
   end
   
   return result
end


--------------------------------------------------------------------------------
-- kernel-smoothed average
--------------------------------------------------------------------------------

function KernelSmoother:smoothKernelAverage(kernel)
   Validations.isFunction(kernel, 'kernel')
   
   local estimates = {}
   for i, x in pairs(self.inputs) do
      local estimate = self:estimateKernelAverage(x, kernel)
      estimates[#estimates + 1] = estimate
   end
   return estimates
end

function KernelSmoother:estimateKernelAverage(query, kernel)
   local trace = false
   Validations.isTensor(query, 'query')
   Validations.isFunction(kernel, 'kernel')

   -- determine kernel-distance from query to each element of training set
   local distances = {}
   local distance = 0
   local sumDistances = 0
   for _, x in ipairs(self.inputs) do
      distance = kernel(query, x)
      distances[#distances + 1] = distance
      sumDistances = sumDistances + distance
   end
   
   -- determine kernel-weighted average of k nearest targets
   local result
   for i=1,#self.inputs do
      if trace and distances[i] ~= 0 then
         print('estimateKernelAverage weight', distances[i] / sumDistances)
      end
      if distances[i] ~= 0 then
         result = 
            (result or 0) + self.targets[i] * (distances[i] / sumDistances)
      end
   end
   if trace then print('estimateKernelAverage result', result) end
   return result
end

--------------------------------------------------------------------------------
-- local linear regression
--------------------------------------------------------------------------------

function KernelSmoother:smoothLocalLinearRegression(kernel)
   Validations.isFunction(kernel, 'kernel')
   
   local estimates = {}
   for i, x in pairs(self.inputs) do
      local estimate = self:estimateLocalLinearRegression(x, kernel)
      estimates[#estimates + 1] = estimate
   end
   return estimates
end

function KernelSmoother:estimateLocalLinearRegression(query, kernel)
   local trace = false
   Validations.isTensor1D(query, 'query')
   Validations.isFunction(kernel, 'kernel')

   -- lazily construct yVector = (targets[1], ..., targets[N])^t
   if self.yVector == nil then
      self.yVector = torch.Tensor(#self.targets)
      for i = 1, #self.targets do
         self.yVector[i] = self.targets[i]
      end
   end
   if trace then print('llr self.yVector', self.yVector) end

   -- lazily construct B^t
   if trace then 
      for i,input in ipairs(self.inputs) do
         print('input', i, input[1])
      end
   end

   if self.bt == nil then
      self.bt = torch.Tensor(1+self.nDimensions, #self.inputs)
      for row = 1, 1 + self.nDimensions do
         for col = 1, #self.inputs do
            if row == 1 then
               self.bt[row][col] = 1
            else
               self.bt[row][col] = self.inputs[col][row - 1]
            end
         end
      end
   end
   if trace then print('llr self.bt\n', self.bt) end

   -- construct W

   local w = torch.Tensor(#self.inputs, #self.inputs):fill(0)
   
   if trace then print('llr query\n', query) end
   for i = 1, #self.inputs do
      w[i][i] = kernel(query, self.inputs[i])
   end
   if trace then print('llr w\n', w) end

   -- construct B^T W, B^T W B, B^T W y
   local btw = self.bt * w
   if trace then print('llr btw\n', btw) end
   local btwb = btw * self.bt:t()
   if trace then print('llr btwb\n', btwb) end
   local btwy = btw * self.yVector
   if trace then print('llr btwy\n', btwy) end

   -- construct (1,query)
   local q1 = torch.Tensor(1 + query:size(1))
   q1[1] = 1
   for i = 1, query:size(1) do
      q1[1 + i] = query[i]
   end
   if trace then print('llr q1\n', q1) end

   -- use the inverse formula for now
   -- later consider solving the linear system
   local btwbInverse = torch.inverse(btwb)
   if trace then print('btwbInverse\n', btwbInverse) end

   local result = q1 * (btwbInverse * btwy)  -- must do in this order
   if trace then print('btwInverse * btwy\n', btwbInverse * btwy) end
   if trace then print('result', result) end

--[[
   -- solve the system AX = rhs where
   -- A = B^T W B
   -- rhs = (1,query) B^T W y
   local rhs = q1 * btwy
   if trace then print('rhs', rhs) end
   local solution = torch.gesv(rhs, btwb)
   print('solution', solution)

   -- estimate the value
   local result = solution[1]
   for i = 1, #self.nDimensions do
      result = result + solution[i] * query[i]
   end
   --]]

   return result
end
   




