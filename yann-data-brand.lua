require 'csv'
data = {}

data.raw = {}
data.raw.age = torch.Tensor(loaded.age)
data.raw.brand = torch.Tensor(loaded.brand)
data.raw.isFemale = torch.Tensor(loaded.female)

data.raw.nSamples = data.raw.age:size(1)

data.cAge = 1       -- the age feature is always the first element of the input vector
data.cIsFemale = 2  -- the isFemale feature is always the second element of the input vector

local function buildInput(age, isFemale)
   local nSamples = age:size(1)
   local input = torch.Tensor(nSamples, 2)
   for sampleIndex = 1, nSamples do
      input[sampleIndex][data.cAge] = age[sampleIndex]
      input[sampleIndex][data.cIsFemale] = isFemale[sampleIndex]
   end
   return input
end

data.train = {}
data.train.input = buildInput(data.raw.age, data.raw.isFemale)
data.train.target = data.raw.brand

-- normalization/shuffling goes here


