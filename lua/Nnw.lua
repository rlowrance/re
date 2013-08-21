-- Nnw.lua
-- common functions for the Nearest Neighbor package

require 'affirm'
require 'makeVerbose'
require 'verify'

-- API overview
if false then
   -- simple average
   ok, estimate = Nnw.estimateAvg(xs, ys, nearestIndices, visible, weights, k)

   -- kernel-weighted average
   ok, estimate = Nnw.estimateKwavg(xs, ys, nearestIndices, visible, weights, k)

   -- local linear regression
   ok,estimate = Nnw.estimateLlr(xs, ys, nearestIndices, visible, weights, k)
   
   -- euclidean distance
   distances = Nnw.euclideanDistances(xs, query)

   -- nearest neighbor distances and indices
   sortedDistances, sortedIndices = Nnw.nearest(xs, query)

   -- weights from the Epanenchnikov kernel
   -- where lambda is the distance to the k-th nearest neighbor
   weights = Nnw.weights(sortedDistances, lambda)
end

Nnw = {}

function Nnw.estimateAvg(xs, ys, nearestIndices, visible, k)
   -- return true, average of k nearest visible neighbors
   -- ignore the weights
   local v, isVerbose = makeVerbose(false, 'Nnw.estimateAvg')
   verify(v, isVerbose,
          {{xs, 'xs', 'isAny'},
           {ys, 'ys', 'isTensor1D'},
           {nearestIndices, 'nearestIndices', 'isTensor1D'},
           {visible, 'visible', 'isTensor1D'},
           {k, 'k', 'isIntegerPositive'}})

   local sum = 0
   local found = 0
   for nearestIndex = 1, nearestIndices:size(1) do
      local obsIndex = nearestIndices[nearestIndex]
      if visible[obsIndex] == 1 then
         found = found + 1
         sum = sum + ys[obsIndex]
         v('obsIndex, y', obsIndex, ys[obsIndex])
         if found == k then 
            break
         end
      end
   end

   if found < k then
      return false, 'not able to find k neighbors'
   else
      local result = sum / k
      v('result', result)
      return true, result
   end
end -- Nnw.estimateAvg

function Nnw.estimateKwavg(k, sortedNeighborIndices, visible, weights, allYs)
   -- ARGS
   -- k                     : integer > 0, number of neighbors to use
   -- sortedNeighborIndices : 1D Tensor
   --                         use first k neighbors that are also visible
   -- visible               : 1D Tensor
   --                         visible[obsIndex] == 1 ==> use this observation
   --                         as a neighbor
   -- weights               : 1D Tensor
   -- allYs                 : 1D Tensor
   -- RETURNS
   -- ok             : true or false
   -- estimate       : number or string
   
   local debug = 0
   local debug = 1  -- investigate if no solution

   local v, isVerbose = makeVerbose(true, 'Nnw.estimateKwavg')
   verify(v, isVerbose,
          {{k, 'k', 'isIntegerPositive'},
           {sortedNeighborIndices, 'sortedNeighborIndices', 'isTensor1D'},
           {visible, 'visible', 'isTensor1D'},
           {weights, 'weights', 'isTensor1D'},
           {allYs, 'allYs', 'isTensor1D'}})

   local sumWeightedYs = 0
   local sumWeights = 0
   local found = 0
   for i = 1, visible:size(1) do
      local obsIndex = sortedNeighborIndices[i]
      if visible[obsIndex] == 1 then
         local weight = weights[i]
         local y = allYs[obsIndex]
         v('i,obsIndex,weight,y', i, obsIndex, weight, y)
         sumWeights = sumWeights + weight
         sumWeightedYs = sumWeightedYs + weight * y
         found = found + 1
         if found == k then
            break
         end
      end
   end
   v('sumWeights', sumWeights)
   v('sumWeightedYs', sumWeightedYs)

   if sumWeights == 0 then
      if debug == 1 then
         print('all weights were zero')
         halt()
      end
      return false, 'all weights were zero'
   elseif found < k then
      if debug == 1 then
         print('found < k')
         halt()
      end
      return false, string.format('only %d obs in neighborhood; k = %d',
                                  found, k)
   else
      local estimate = sumWeightedYs / sumWeights
      v('estimate', estimate)
      return true, estimate
   end
end -- Nnw.estimateKwavg

local function printZeroRowsCols(name, a, featureNames)
   -- return indices of all-zero columns
   print(string.format('Zero rows and columns of %s:', name))
   local nRows = a:size(1)
   local nCols = a:size(2)
   for rowIndex = 1, nRows do
      local allZero = true
      for colIndex = 1, nCols do
	 if a[rowIndex][colIndex] ~= 0 then
	    allZero = false
	 end
      end
      if allZero then
	 print(string.format(' row %d is all zero', rowIndex))
      end
   end
   local allZeroColIndices = {}
   for colIndex = 1, nCols do
      local allZero = true
      for rowIndex = 1, nRows do
	 if a[rowIndex][colIndex] ~= 0 then
	    allZero = false
	 end
      end
      if allZero then
	 print(string.format(' col %d (%s) is all zero', 
                             colIndex, featureNames[colIndex]))
	 allZeroColIndices[#allZeroColIndices + 1] = colIndex
      end
   end
   return allZeroColIndices
end -- printZeroRowsCols

local function printWeights(wVector)
   local line = 'wVector: '
   for i = 1, wVector:size(1) do
      line = line .. string.format('%.4f', wVector[i]) .. ' '
   end
   print(line)
end -- printWeights

local function printColumnNames(colNames, indices)
   print('all-zero feature column names in B matrix: ')
   for i = 1, #indices do
      local index = indices[i]
      print(string.format(' [%d] = %s', index, colNames[index]))
   end
end -- printColumnNames

function Nnw.estimateLlr(k, regularizer,
                        sortedNeighborIndices, visible, weights, 
                        query, allXs, allYs)
   -- ARGS
   -- k                     : integer > 0, number of neighbors to use
   -- regularizer           : number >= 0, added to each weight
   -- sortedNeighborIndices : 1D Tensor
   --                         use first k neighbors that are also visible
   -- visible               : 1D Tensor
   --                         visible[obsIndex] == 1 ==> use this observation
   --                         as a neighbor
   -- weights               : 1D Tensor
   -- allXs                 : 2D Tensor
   -- allYs                 : 1D Tensor
   -- RETURNS
   -- ok             : true or false
   -- estimate       : number or string

   local debug = 0
   local debug = 1  -- determine why inverse fails
   local version = 'solve' -- 'invert', 'solve', or 'both'
   local v, isVerbose = makeVerbose(false, 'Nnw.estimateLlr')
   verify(v, isVerbose,
          {{k, 'k', 'isIntegerPositive'},
           {regularizer, 'regularizer', 'isNumberNonNegative'},
           {sortedNeighborIndices, 'sortedNeighborIndices', 'isTensor1D'},
           {visible, 'visible', 'isTensor1D'},
           {weights, 'weights', 'isTensor1D'},
           {query, 'query', 'isTensor1D'},
           {allXs, 'allXs', 'isTensor2D'},
           {allYs, 'allYs', 'isTensor1D'}})

   assert(allYs:size(1) == allXs:size(1),
          'allXs and allYs must have same number of observations')
   
   local nDims = allXs:size(2)

   assert(k > nDims,
          string.format('undetermined since k(=%d) <= nDims (=%d)',
                        k, nDims))

   -- Yann suggests normalizing the weights so that they sum to 1
   local nWeights = weights:size(1)
   local sumWeights = 0
   for i = 1, nWeights do
      local weight = weights[i]
      assert(weight >= 0, string.format('weight (=%f) is negative', weight))
      sumWeights = sumWeights + weight
   end
   assert(sumWeights > 0, 'all weights are zero')

   local normalizedWeights = torch.Tensor(weights:size(1))
   for i = 1, nWeights do
      normalizedWeights[i] = weights[i] / sumWeights
   end
   v('normalizedWeights', normalizedWeights)
   
   -- create regression matrix B
   -- by prepending a 1 in the first position
   local B = torch.Tensor(k, nDims + 1)
   local selectedYs = torch.Tensor(k)
   local wVector = torch.Tensor(k)
   local found = 0
   for i = 1, allXs:size(1) do
      local obsIndex = sortedNeighborIndices[i]
      if visible[obsIndex] == 1 then
         found = found + 1
         v('i,obsIndex,found', i, obsIndex, found)
         B[found][1] = 1
         for d = 1, nDims do
            B[found][d+1] = allXs[obsIndex][d]
         end
         selectedYs[found] = allYs[obsIndex]
         wVector[found] = normalizedWeights[i]
         if found == k then
            break
         end
      end
   end
   v('nObs, nDims', nObs, nDims)
   v('B (regression matrix)', B)
   v('selectedYs', selectedYs)
   v('wVector', wVector)

   -- also prepend a 1 in the first position of the query
   -- to make the final multiplication work, the prepended query needs to be 2D
   local extendedQuery = torch.Tensor(1, nDims + 1)
   extendedQuery[1][1] = 1
   for d = 1, nDims do
      extendedQuery[1][d + 1] = query[d]
   end
   v('extendedQuery', extendedQuery)

   local BT = B:t()        -- transpose B
   local W = DiagonalMatrix(wVector)
   v('BT', BT)
   v('W', W) 
   
   -- BTWB = B^T W B
   local BTWB = BT * (W:mul(B))
   v('BTWB', BTWB)
   v('BTWB:size()', BTWB:size())

   -- add in the regularizer to every position on the diagonal but the first
   for d = 2, BTWB:size(1) do
      BTWB[d][d] = BTWB[d][d] + regularizer
   end
   
   -- now BTWB includes the regularizer

   -- determine betas
   local betasInvert 
   local betasSolve
   v('version', version)
   if version == 'invert' or version == 'both' then
      -- invert BTWB, catching error
      local ok, BTWBInv = pcall(torch.inverse, BTWB)
      if not ok then
         -- if the error message is "getrf: U(i,i) is 0, U is singular"
         -- then LU factorization succeeded but U is exactly 0, so that
         --      division by zero will occur if U is used to solve a
         --      system of equations
         -- ref: http://dlib.net/dlib/matrix/lapack/getrf.h.html
         if debug == 1 then 
            print('Llr:estimate: error in call to torch.inverse')
            print('error message = ' .. BTWBInv)
            print('BTWB size = ' .. tostring(BTWB:size()))
            printZeroRowsCols('BTWB', BTWB, globalFeatureColumnNames)
            local zeroColIndices = printZeroRowsCols('B', B)
            printWeights(wVector)
            if globalFeatureColumnNames ~= nil then
               -- readTrainingData saved the column names in this global, if
               -- redundant features were dropped
               printColumnNames(globalFeatureColumnNames, zeroColIndices)
            end
            print('k', k)
            print('regularizer', regularizer)
            error(BTWBInv)
         end
         return false, BTWBInv  -- return the error message
      end
      betasInvert =  BTWBInv * BT * W:mul(selectedYs)
      v('betasInvert', betasInvert)
   end
   if version == 'solve' or version == 'both' then
      -- solve AX = B where
      --   A = BTWB (with regularizer)
      --   B = BTWy
      local B = BT * W:mul(selectedYs) -- TODO: factor out B (use in Invert)
      -- B must be 2D
      local B2D = torch.Tensor(B:size(1), 1)
      for i = 1, B:size(1) do
         B2D[i][1] = B[i]
      end
      v('size B2D', B2D:size())
      v('size BTWB', BTWB:size())
      betasSolve2D = torch.gesv(B2D, BTWB)
      v('betasSolve2D', betasSolve2D)
      -- remove extra dimension
      betasSolve = torch.Tensor(betasSolve2D:size(1))
      for i = 1, betasSolve:size(1) do
         betasSolve[i] = betasSolve2D[i][1]
      end
   end

   if betasInvert and betasSolve then
      -- compare the two
      print('comparison of the beta values')
      print('size betasInvert =' , betasInvert:size())
      print('size betasSolve  =', betasSolve:size())
      print(string.format(' %2s %10s %10s', 'i', 'invert', 'solve'))
      for i = 1, betasInvert:size(1) do
         print(string.format(' %2d %10.5f %10.5f',
                             i, betasInvert[i], betasSolve[i]))
      end
      halt()
   end

   -- TODO: use one of the beta's
   --local betas =  BTWBInv * BT * W:mul(selectedYs)
   --local estimate1 = extendedQuery * BTWBInv * BT * W:mul(selectedYs)
   --v('estimate1', estimate1)
   local estimate
   if betasInverse then
      estimate = extendedQuery * betasInverse
   else
      estimate = extendedQuery * betasSolve
   end
   --local estimate = extendedQuery * betas
   v('extendedQuery', extendedQuery)
   --v('beta', BTWBInv * BT * W:mul(selectedYs))
   v('estimate', estimate[1])


   affirm.isTensor1D(estimate, 'estimate')
   assert(1 == estimate:size(1))
   return true, estimate[1]
end -- Nnw.estimateLlr


function Nnw.euclideanDistance(x, query)
   -- return scalar Euclidean distance
   local debug = 0
   --debug = 1  -- zero value for lambda
   local v, isVerbose = makeVerbose(false, 'Nnw:euclideanDistance')
   verify(v, isVerbose,
          {{x, 'x', 'isTensor1D'},
           {query, 'query', 'isTensor1D'}})
   assert(x:size(1) == query:size(1))
   local ds = x - query
   if debug == 1 then
      for i = 1, x:size(1) do
         print(string.format('x[%d] %f query[%d] %f ds[%d] %f',
                             i, x[i], i, query[i], i, ds[i]))
      end
   end
   v('ds', ds)
   local distance = math.sqrt(torch.sum(torch.cmul(ds, ds)))
   v('distance', distance)
   return distance
end -- euclideanDistance

function Nnw.euclideanDistances(xs, query)
   -- return 1D tensor such that result[i] = EuclideanDistance(xs[i], query)
   -- We require use of Euclidean distance so that this code will work.
   -- It computes all the distances from the query point at once
   -- using Clement Farabet's idea to speed up the computation.

   local v, isVerbose = makeVerbose(false, 'Nnw:euclideanDistances')
   verify(v,
          isVerbose,
          {{xs, 'xs', 'isTensor2D'},
           {query, 'query', 'isTensor1D'}})
            
   assert(xs:size(2) == query:size(1),
          'number of columns in xs must equal size of query')

   -- create a 2D Tensor where each row is the query
   -- This construction is space efficient relative to replicating query
   -- queries[i] == query for all i in range
   -- Thanks Clement Farabet!
   local queries = 
      torch.Tensor(query:clone():storage(),-- clone in case query is a row of xs
                   1,                    -- offset
                   xs:size(1), 0,   -- row index offset and stride
                   xs:size(2), 1)   -- col index offset and stride
      
   local distances = torch.add(queries, -1 , xs) -- queries - xs
   distances:cmul(distances)                          -- (queries - xs)^2
   distances = torch.sum(distances, 2):squeeze() -- \sum (queries - xs)^2
   distances = distances:sqrt()                  -- Euclidean distances
  
   v('distances', distances)
   return distances
end -- Nnw.euclideanDistances

function Nnw.nearest(xs, query)
   -- find nearest observations to a query
   -- RETURN
   -- sortedDistances : 1D Tensor 
   --                   distances of each xs from query
   -- sortedIndices   : 1D Tensor 
   --                   indices that sort the distances
   local v, isVerbose = makeVerbose(false, 'Nnw.nearest')
   verify(v, isVerbose,
          {{xs, 'xs', 'isTensor2D'},
           {query, 'query', 'isTensor1D'}})
   local distances = Nnw.euclideanDistances(xs, query)
   v('distances', distances)
   local sortedDistances, sortedIndices = torch.sort(distances)
   v('sortedDistances', sortedDistances)
   v('sortedIndices', sortedIndices)
   return sortedDistances, sortedIndices
end -- Nnw.nearest

function Nnw.weights(sortedDistances, lambda)
   -- return values of Epanenchnov kernel using euclidean distance
   local v, isVerbose = makeVerbose(false, 'KernelSmoother.weights')
   verify(v, isVerbose,
          {{sortedDistances, 'sortedDistances', 'isTensor1D'},
           {lambda, 'lambda', 'isNumberPositive'}})
   local nObs = sortedDistances:size(1)

   local t = sortedDistances / lambda
   v('t', t)

   local one = torch.Tensor(nObs):fill(1)
   local indicator = torch.le(torch.abs(t), one):type('torch.DoubleTensor')
   v('indicator', indicator)

   local dt = torch.mul(one - torch.cmul(t, t), 0.75)
   v('dt', dt)

   -- in torch, inf * 0 --> nan (not zero)
   local weights = torch.cmul(dt, indicator)
   v('weights', weights)

   return weights
end -- Nnw.weights
