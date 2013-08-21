-- generate brand data in form of UCLA brand data but with known generation
-- use the coefficients from the UCLA data set!

-- usage example:
-- cd src.git/lua/impute-ground-truth
-- lua generate-data.lua

--[[
summary(mlogit.model)

Call:
mlogit(formula = brand ~ 1 | female + age, data = mldata, reflevel = "1", 
    method = nr, print.level = 0)

Frequencies of alternatives:
      1       2       3 
0.28163 0.41769 0.30068 

nr method
5 iterations, 0h:0m:0s 
g(-H)^-1g = 0.00158 
successive fonction values within tolerance limits 

Coefficients :
                Estimate Std. Error  t-value  Pr(>|t|)    
2:(intercept) -11.774478   1.774612  -6.6350 3.246e-11 ***
3:(intercept) -22.721201   2.058028 -11.0403 < 2.2e-16 ***
2:female        0.523813   0.194247   2.6966  0.007004 ** 
3:female        0.465939   0.226090   2.0609  0.039316 *  
2:age           0.368201   0.055003   6.6942 2.169e-11 ***
3:age           0.685902   0.062627  10.9523 < 2.2e-16 ***
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1 

Log-Likelihood: -702.97
McFadden R^2:  0.11676 
Likelihood ratio test : chisq = 185.85 (p.value = < 2.22e-16)

--]]

require "csv"

-- set number of observations
NUMOBS = 7350
print(string.format("generating %d observations", NUMOBS))

-- initialize random number generator (for reproducability)
randomseed = 27
math.randomseed(27)

-- return 1 iff b
function indicator(b)
   if b then return 1 else return 0 end
end

-- generate age by sampling uniformly from set {20, 21, ..., 40}
-- generate female variable by sampling uniformly from set {0,1}
age = {}
female = {}
for i = 1,NUMOBS do
   age[#age+1] = math.random(20,40)
   female[#female+1] = indicator(math.random() < 0.5)
end

-- define functions that return unnormalized probabilities
-- use values from mlogit for the UCLA brand data set
-- located in directory test-impute-brands-ucla-example
function uprob1(age,female)
   return math.exp(0)
end

function uprob2(age,female)
   return math.exp(-11.774478 + 0.52813*female + 0.368201*age)
end

function uprob3(age,female)
   return math.exp(-22.721201 + 0.465939*female + 0.685902*age)
end

-- return index of maximum argument
function maxarg(a,b,c)
   local maxvalue = math.max(a,b,c)
   if     a == maxvalue then return 1
   elseif b == maxvalue then return 2
   else                      return 3
   end
end


-- pick most probable brands
brand = {}
for i = 1,NUMOBS do
   brand[#brand+1] = maxarg(uprob1(age[i],female[i]),
			    uprob2(age[i],female[i]),
			    uprob3(age[i],female[i]))
end

-- write as csv file
-- use same file name as for the UCLA data
csv = Csv:new("mlogit.csv", "w")

-- write header row
csv:write({"brand", "female", "age"})

-- write data rows
for i = 1,NUMOBS do
   csv:write({brand[i], female[i], age[i]})
end

csv:close()
