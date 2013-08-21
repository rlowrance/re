-- Resampling.lua
-- class for resampling (non-parametric) statitics

-- source: Shasha, Statistics is Easy
-- This code is largely a port of the code that comes with the book.

local Resampling = torch.class('Resampling')

--------------------------------------------------------------------------------
-- coinExample
--------------------------------------------------------------------------------

-- prob of 15 heads in 17 tosses
function Resampling.coinExample()
   -- return number of heads
   local function experiment()
      local numHeads = 0
      for tossNumber = 1, 17 do
         local result
         if torch.uniform() < 0.5 then
            result = 'heads'
         else
            result = 'tails'
         end
         if result == 'heads' then numHeads = numHeads + 1 end
      end
      return numHeads
   end -- experiment
         
   -- do 10,000 trials of the experiment
   local count = {}
   local numTrials = 10000
   for i=1,numTrials do
      local numHeads = experiment()
      count[numHeads] = (count[numHeads] or 0) + 1
   end
   for k,v in pairs(count) do
      print(k, v, v/numTrials)
   end
end

--------------------------------------------------------------------------------
-- areaToSd, sdToArea
--------------------------------------------------------------------------------

-- associate proportion of values above the mean to the number of standard
-- deviations above the mean
local area_to_sd_map = {
0.0000, 0.0040, 0.0080, 0.0120, 0.0160, 0.0199, 0.0239, 0.0279, 0.0319, 0.0359,
0.0398, 0.0438, 0.0478, 0.0517, 0.0557, 0.0596, 0.0636, 0.0675, 0.0714, 0.0753,
0.0793, 0.0832, 0.0871, 0.0910, 0.0948, 0.0987, 0.1026, 0.1064, 0.1103, 0.1141,
0.1179, 0.1217, 0.1255, 0.1293, 0.1331, 0.1368, 0.1406, 0.1443, 0.1480, 0.1517,
0.1554, 0.1591, 0.1628, 0.1664, 0.1700, 0.1736, 0.1772, 0.1808, 0.1844, 0.1879,
0.1915, 0.1950, 0.1985, 0.2019, 0.2054, 0.2088, 0.2123, 0.2157, 0.2190, 0.2224,
0.2257, 0.2291, 0.2324, 0.2357, 0.2389, 0.2422, 0.2454, 0.2486, 0.2517, 0.2549,
0.2580, 0.2611, 0.2642, 0.2673, 0.2704, 0.2734, 0.2764, 0.2794, 0.2823, 0.2852,
0.2881, 0.2910, 0.2939, 0.2967, 0.2995, 0.3023, 0.3051, 0.3078, 0.3106, 0.3133,
0.3159, 0.3186, 0.3212, 0.3238, 0.3264, 0.3289, 0.3315, 0.3340, 0.3365, 0.3389,
0.3413, 0.3438, 0.3461, 0.3485, 0.3508, 0.3531, 0.3554, 0.3577, 0.3599, 0.3621,
0.3643, 0.3665, 0.3686, 0.3708, 0.3729, 0.3749, 0.3770, 0.3790, 0.3810, 0.3830,
0.3849, 0.3869, 0.3888, 0.3907, 0.3925, 0.3944, 0.3962, 0.3980, 0.3997, 0.4015,
0.4032, 0.4049, 0.4066, 0.4082, 0.4099, 0.4115, 0.4131, 0.4147, 0.4162, 0.4177,
0.4192, 0.4207, 0.4222, 0.4236, 0.4251, 0.4265, 0.4279, 0.4292, 0.4306, 0.4319,
0.4332, 0.4345, 0.4357, 0.4370, 0.4382, 0.4394, 0.4406, 0.4418, 0.4429, 0.4441,
0.4452, 0.4463, 0.4474, 0.4484, 0.4495, 0.4505, 0.4515, 0.4525, 0.4535, 0.4545,
0.4554, 0.4564, 0.4573, 0.4582, 0.4591, 0.4599, 0.4608, 0.4616, 0.4625, 0.4633,
0.4641, 0.4649, 0.4656, 0.4664, 0.4671, 0.4678, 0.4686, 0.4693, 0.4699, 0.4706,
0.4713, 0.4719, 0.4726, 0.4732, 0.4738, 0.4744, 0.4750, 0.4756, 0.4761, 0.4767,
0.4772, 0.4778, 0.4783, 0.4788, 0.4793, 0.4798, 0.4803, 0.4808, 0.4812, 0.4817,
0.4821, 0.4826, 0.4830, 0.4834, 0.4838, 0.4842, 0.4846, 0.4850, 0.4854, 0.4857,
0.4861, 0.4864, 0.4868, 0.4871, 0.4875, 0.4878, 0.4881, 0.4884, 0.4887, 0.4890,
0.4893, 0.4896, 0.4898, 0.4901, 0.4904, 0.4906, 0.4909, 0.4911, 0.4913, 0.4916,
0.4918, 0.4920, 0.4922, 0.4925, 0.4927, 0.4929, 0.4931, 0.4932, 0.4934, 0.4936,
0.4938, 0.4940, 0.4941, 0.4943, 0.4945, 0.4946, 0.4948, 0.4949, 0.4951, 0.4952,
0.4953, 0.4955, 0.4956, 0.4957, 0.4959, 0.4960, 0.4961, 0.4962, 0.4963, 0.4964,
0.4965, 0.4966, 0.4967, 0.4968, 0.4969, 0.4970, 0.4971, 0.4972, 0.4973, 0.4974,
0.4974, 0.4975, 0.4976, 0.4977, 0.4977, 0.4978, 0.4979, 0.4979, 0.4980, 0.4981,
0.4981, 0.4982, 0.4982, 0.4983, 0.4984, 0.4984, 0.4985, 0.4985, 0.4986, 0.4986,
0.4987, 0.4987, 0.4987, 0.4988, 0.4988, 0.4989, 0.4989, 0.4989, 0.4990, 0.4990}

function sdToArea(sd)
   local sign = 1
   if sd < 0 then sign = -1 end
   sd = math.abs(sd)
   local index = math.floor(sd * 100)
   if #area_to_sd_map <= index then
      return sign * area_to_sd_map[-1] -- return last element in array
   end
   if index == (sd * 100) then
      return sign * area_to_sd_map[index]
   end
   return sign * (area_to_sd_map[index] + area_to_sd_map[index + 1]) / 2
end

function areaToSd(area)
   local sign = 1
   if area < 0 then sign = -1 end
   area = math.abs(area)
   for i,mapValue in ipairs(area_to_sd_map) do
      if area == mapValue then
         return sign * i / 100
      elseif 1 < i and 
             area_to_sd_map[i - 1] < area and 
             area < area_to_sd_map[i] then
         -- our area is between this value and the previous
         -- we will just take the sd half way between i - 1 and i
         return sign * (i - .5) / 100
      end
   end
   return sign * (#area_to_sd_map - 1) / 100
end

--------------------------------------------------------------------------------
-- bootstrap
--------------------------------------------------------------------------------

-- return an array of #a with members drawn with replacement from a
-- + a : a array
local function bootstrap(a)
   local result = {}
   for i = 1, #a do
      result[#result + 1] = a[math.floor(torch.uniform(1, #a))]
   end
   --print('bootstrap a', a)
   --print('bootstrap result', result)
   return result
end

--------------------------------------------------------------------------------
-- concatenate
--------------------------------------------------------------------------------

-- return concatenation of arrays
local function concatenate(a, b)
   local result = {}
   for _, v in pairs(a) do 
      result[#result + 1] = v
   end
   for _, v in pairs(b) do
      result[#result + 1] = v
   end
   return result
end

--------------------------------------------------------------------------------
-- mean
--------------------------------------------------------------------------------

local function mean(table)
   local sum = 0
   local count = 0
   for _,v in pairs(table) do
      sum = sum + v
      count = count + 1
   end
   return sum / count
end

--------------------------------------------------------------------------------
-- meanDiff
--------------------------------------------------------------------------------

-- difference of means
function meanDiff(groupA, groupB)
   return mean(groupA) - mean(groupB)
end

--------------------------------------------------------------------------------
-- randomPermutationIndices
--------------------------------------------------------------------------------

-- return a uniformly at random permuation of {1, 2, ..., n} as an array
-- ref: http://en.wikipedia.org/wiki/Random_permutation
function randomPermutationIndices(n)
   local randomIndexs = {}
   for i = 1, n do 
       randomIndexs[#randomIndexs + 1] = {torch.uniform(0,1), i} end
   table.sort(randomIndexs, function(a,b) return a[1] < b[1] end)
   local result = {}
   for _,v in ipairs(randomIndexs) do
       result[#result + 1]= v[2]
   end
   return result
end

--------------------------------------------------------------------------------
-- shuffle
--------------------------------------------------------------------------------

-- Takes an array of groups (two or more arrays), pools all values, and makes
-- new groups the same size of the original groups.
-- Returns these new groups
function shuffle(groups)
   trace = false
   local pool = {}
   for _, next in pairs(groups) do
      for _, v in pairs(next) do
         pool[#pool + 1 ] = v
      end
   end
   
   -- mix them up
   local randomPermuation = randomPermutationIndices(#pool)
   if trace then
      for i,v in ipairs(randomPermuation) do
         print(i, v, pool[v])
      end
   end

    -- reassign to new groups each the same size as the original groups
    local result = {}
    local index = 0
    for _,next in pairs(groups) do
        if trace then print('next', next) end
        local nextGroup = {}
        for i=1,#next do
            index = index + 1
            nextGroup[#nextGroup + 1] = pool[randomPermuation[index]]
        end
        result[#result + 1] = nextGroup
    end
    
    return result
end




--------------------------------------------------------------------------------
-- diff2MeansConf
--------------------------------------------------------------------------------

-- Confidence interval for differences bewteen two means
-- + group1       : array of numbers
-- + group2       : array of numbers
-- + confInterval : optional number in [0,1], size of confidence interval
-- return a, b such that (a,b) is
-- confidence range for the requested confInterval
function Resampling.diff2MeansConf(group1, group2, confInterval)
   confInterval = confInterval or 0.90
   local all = concatenate(group1, group2)
   local observedDiff = meanDiff(group1, group2)

   local sampledDifferences = {}
   local numResamples = 10000
   for i=1,numResamples do
      local groupA = bootstrap(group1)
      local groupB = bootstrap(group2)
      local sampleDiff = meanDiff(groupA, groupB)
      --print('sampleDiff', sampleDiff)
      sampledDifferences[#sampledDifferences + 1] = sampleDiff 
   end
   table.sort(sampledDifferences)
   --print('sampledDifferences', sampledDifferences)

   local tails = (1 - confInterval) / 2
   local lowerBound = math.floor(math.ceil(numResamples * tails))
   local upperBound = math.floor(math.floor(numResamples * (1 - tails)))
   print(lowerBound, upperBound)

   print()
   print('Results from diff2MeansConf: confidence intervals for difference' ..
         ' of two means')
   print(string.format('Mean of group 1 : %f', mean(group1)))
   print(string.format('Mean of group 2 : %f', mean(group2)))
   print(string.format('Observed difference between the means: %f',
                       observedDiff))
   print()
   print(string.format('We have %f confidence that the true difference between'
                       .. ' the means',
                       confInterval))
   local a = sampledDifferences[lowerBound]
   local b = sampledDifferences[upperBound]
   print(string.format('is between: %f and %f.', a, b))
   return a, b
end

--------------------------------------------------------------------------------
-- diff2MeanSig
--------------------------------------------------------------------------------

-- significance of the difference in the means of two groups
function Resampling.diff2MeansSig(group1, group2)
   local all = concatenate(group1, group2)
   local observedDiff = meanDiff(group1, group2)

   local count = 0
   local numResamples = 10000
   for i=1,numResamples do
      local newSamples = shuffle({group1,group2})
      local newMeanDiff = meanDiff(newSamples[1], newSamples[2])
      -- if observed diff is negative, look for differences that are smaller
      -- if observed diff is positive, look for differences that are larger
      if observedDiff < 0 and newMeanDiff <= observedDiff then
          count = count + 1
      elseif observedDiff > 0 and newMeanDiff >= observedDiff then
          count = count + 1
      end 
   end
    
   print()
   print('Results from diff2MeansSig: ' ..
	 'significance of difference in two means')
   print(string.format('Mean of group 1 : %f', mean(group1)))
   print(string.format('Mean of group 2 : %f', mean(group2)))
   print(string.format('Observed difference between the means: %f',
                       observedDiff))
   local phrase
   if observedDiff < 0 then
      phrase = 'less than or equal to'
   else
      phrase = 'greater than or equal to'
   end
   local prob = count / numResamples

   print()
   print(string.format(
            '%d out of %d experiments\nhad a difference of two means ' ..
            '%s %f.',
            count, numResamples, phrase, prob))
   print()
   print(
      string.format('The chance of getting a difference of two means\n'..
                     '%s %f is %f.',
                     phrase, observedDiff, prob))

   return prob
   end

    
--------------------------------------------------------------------------------
-- meanConf
--------------------------------------------------------------------------------

-- Confidence interval for the mean
-- + sample       :        array of numbers
-- + confInterval : number, the confidence interval
-- + result1      : number, low end of confidence bound
-- + result2      : number, high end of confidence bound
function Resampling.meanConf(sample, confInterval)
   confInterval = confInterval or .90
   local observedMean = mean(sample)
   local numResamples = 10000
   local countBelowMean = 0
   local bootMeans = {}
   for i=1,numResamples do
      local bootstrapMean = mean(bootstrap(sample)) 
      bootMeans[#bootMeans + 1] = bootstrapMean
      if bootstrapMean < observedMean then
         countBelowMean = countBelowMean + 1
      end
   end
   table.sort(bootMeans)
   local tails = (1 - confInterval) / 2
   local lowerBound = math.floor(math.ceil(numResamples * tails))
   local upperBound = math.floor(math.floor(numResamples * (1 - tails)))
   local p = countBelowMean / numResamples
   local distFromCenter = p - .5
   local z0 = areaToSd(distFromCenter)

   -- find proportion that should be between the mean and one of the tail
   local tailSds = areaToSd(confInterval / 2)
   local zAlphaOver2 = 0 - tailSds
   local z1MinusAlphaOver2 = tailSds

   -- decrease range if the lower and upper bounds are not integers
   local biasCorrectedLowerBound = 
      math.floor(math.ceil(numResamples * 
                           (0.5 + sdToArea(zAlphaOver2 + (2 * z0)))))
   local biasCorrectedUpperBound =
      math.floor(math.floor(numResamples *
                            (0.5 + sdToArea(z1MinusAlphaOver2 + (2 * z0)))))
      
   print()
   print('meanConf: Confidence interval for mean')
   print(string.format('Observed mean: %f', observedMean))
   print(
      string.format('We have %f confidence interval that the true mean', 
                    confInterval))
   local low = bootMeans[biasCorrectedLowerBound]
   local high = bootMeans[biasCorrectedUpperBound]
   print(
      string.format('is between %f and %f.', low, high))
   
   return low, high
end
