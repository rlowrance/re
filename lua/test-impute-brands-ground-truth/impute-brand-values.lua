-- impute-ucla-brand-values.lua
-- Use coefficients from logistic regression to impute the brand values
-- match to known probabilities file from ucla

-- invocation example: on local
--  cd .../src.git/lua
--  lua impute-ucla-brand-values.lua

require 'torch'
require 'csv'

-- select files used

dir = ""  -- data files are in current directory

datafilename = "mlogit.csv"
mlogitfilename = "mlogit-summary-7350-observations.txt"

function indexof(featurename, header)
   for i = 1,#header do
      if featurename == header[i] then return i end
   end
   print("header", header)
   error("featurename " .. featurename .. " not in header")
end

-- return array from 1st field in a csv file
-- filename is also the only column in the file
-- obs is the name of the observation set: "1A" or "2R"
function readfeature(featurename)
   print("reading feature", featurename)
   local csv = Csv:new(dir .. datafilename, "r")
   local featureindex = indexof(featurename, csv:read())
   local res = {}
   while true do
      local data = csv:read()
      if not data then break end
	 res[#res+1] = data[featureindex] + 0 -- convert to number
   end
   return res
end

brand = readfeature("brand")
female = readfeature("female")
age = readfeature("age")


--print first 10 entries in array
function printhead(name, a) 
   for i = 1,10 do
      print(name .. "[" .. i .. "]=" .. a[i])
   end
end

if false then
   printhead("brand", brand)
   printhead("female", female)
   printhead("age", age)
end

-- read R's mlogit result file to determine the beta values for
-- the 3 levels

mlogitfile = io.input(dir .. mlogitfilename)

-- skip up to line starting "Coefficients :"
while true do
   local line = io.read()
   if string.find(line, "^Coefficients :") then break end
end

io.read() -- ignore heading line

-- build up the beta values, one for each to-be imputed field
brand2 = {}  -- #2 in mlogit output
brand3 = {}  -- #3 in mlogit output

function setbetavar(var, attribute)
   local line = io.read()   
   local pattern = "%d:%p*" .. attribute .. "%p*%s+([-]*%d+%.%d+)"
   local value = string.match(line, pattern)
   if value 
   then var[attribute] = value + 0
   else error("did not find " .. attribute .. 
	      " in\n" .. line .. 
	      "\nwith pattern=" .. pattern)
   end
end

function setbetas(attribute)
   setbetavar(brand2, attribute)
   setbetavar(brand3, attribute)
end

setbetas("intercept")
setbetas("female")
setbetas("age")

function printbeta(name, t)
   print(string.format("%s intercept %f female %f age %f",
		       name, t.intercept, t.female, t.age))
end

printbeta("brand2", brand2)
printbeta("brand3", brand3)


function printvar(name, v)
   print("var",name)
   for key,value in pairs(v) do
      print(key,value)
   end
end

if true then
   printvar("brand2", brand2)
   printvar("brand3", brand3)
end 

--[[
-- Combine FOUNDATION CODE levels into one categorial feature
-- FOUNDATION CODE with level 1 .. 7
print("#acres", #acres)
foundationcode = {}
for i = 1, #acres do
   foundationcode[#foundationcode+1] = 
      (foundationcodeis001[i] * 1) +
      (foundationcodeiscre[i] * 2) +
      (foundationcodeismsn[i] * 3) +
      (foundationcodeispir[i] * 4) +
      (foundationcodeisras[i] * 5) +
      (foundationcodeisslb[i] * 6) +
      (foundationcodeisucr[i] * 7)
end

if false then
   print("#foundationcode", #foundationcode)
   printhead("foundcationis001", foundationcodeis001)
   printhead("foundcationiscre", foundationcodeiscre)
   printhead("foundcationismsn", foundationcodeismsn)
   printhead("foundcationispir", foundationcodeispir)
   printhead("foundcationisras", foundationcodeisras)
   printhead("foundcationisslb", foundationcodeisslb)
   printhead("foundcationisucr", foundationcodeisucr)
   printhead("foundationcode", foundationcode)
end

function countkeyoccurences(t)
   res = {}
   for key,value in pairs(t) do
      if res[value] 
      then res[value] = res[value] + 1 
      else res[value] = 1 
      end
   end
   return res
end

actualcounts = countkeyoccurences(foundationcode)

function printtable(t)
   for key,value in pairs(t) do print(key,value) end
end

print("actual foundation code counts")
printtable(actualcounts)
   --]]

-- imput values for brand

-- logit(i) = beta(i)' * x(i)
function logit(beta,i)
   return
      beta.intercept +
      beta.female * female[i] +
      beta.age * age[i]
end

-- return prediction for observation i
-- also print, if among first 30 observations
-- predict and print  brand code probabilities for observation i
function predict(i) 
   local uprob1 = math.exp(0)
   local uprob2 = math.exp(logit(brand2, i))
   local uprob3 = math.exp(logit(brand3, i)) -- ERROR IN THIS LINE

   local sum = uprob1 + uprob2 + uprob3
   local prob1 = uprob1 / sum
   local prob2 = uprob2 / sum
   local prob3 = uprob3 / sum

   local maxprob = math.max(prob1, prob2, prob3)
   local predicted = 0
   if     maxprob == prob1 then predicted = 1
   elseif maxprob == prob2 then predicted = 2
   elseif maxprob == prob3 then predicted = 3
   else                         error("impossible")
   end
   
   local same = predicted == brand[i]

   if i <= 30 then
      print(string.format("%2d %d %d %f %f %f %d %d %s",
			  i, age[i], female[i],
			  prob1, prob2, prob3, 
			  predicted, brand[i], tostring(same)))  
   end

   return predicted, same
end

countsame = 0
for i = 1,#brand do
   local _, same = predict(i)
   if same then countsame = countsame + 1 end
end

print("same", countsame)
print("# observations", #brand)
print("same/# observations", countsame/#brand) 

-- TODO: compare to original; count failures and successes

