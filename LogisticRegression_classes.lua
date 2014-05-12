-- LogisticRegression_classes.lua
-- salience-weighted logistic regression

if false then
   -- API overview
   model = LogisticRegressionModel(nFeatures, nClasses)
   criterion = LogisticRegressionCriterion()

   local loss, lossGradient = LogisticRegression.makeFunctions(augmentedX, y, s, nClasses, l2)
   local lossValue = loss(theta)
   local lossValue, gradientValue = lossGradient(theta)
end

require 'makeVp'
require 'nn'
require 'pp'
require 'torch'

LogisticRegression = {}

-------------------------------------------------------------------------------
-- Model
-------------------------------------------------------------------------------

local LogisticRegressionModel, parent = torch.class('LogisticRegressionModel', 'nn.Module')

-- constuction logistic regression model with output = log (prob_{i,c})
-- ARGS:
-- nFeatures : number of features in augmented input X
-- nClasses  : number of classes
function LogisticRegressionModel:__init(nFeatures, nClasses)
   print('LogisticRegressionModel constructor') print('nFeatures', nFeatures) print('nClasses') print(nClasses)
   parent.__init(self)
   self.model = nn.Sequential()
   self.model:add(nn.Linear(nFeatures, nClasses))
   self.model:add(nn.LogSoftMax())
   pp.table('self.model', self.model)
end

function LogisticRegressionModel:updateOutput(input)
   self.model:updateOutput(input)
   return self.model.output
end

function LogisticRegressionModel:updateGradInput(input, gradOutput)
   self.model:updateGradInput(input, gradOutput)
   return self.model.gradInput
end

function LogisticRegressionModel:accGradParameters(input, gradOutput, scale)
   self.model:accGradParameters(input, gradOutput, scale)
end


-------------------------------------------------------------------------------
-- Criterion
-------------------------------------------------------------------------------

local LogisticRegressionCriterion, parent = torch.class('LogisticRegressionCriterion', 'nn.Module')

function LogisticRegressionCriterion:__init()
   parent.__init(self)
end

-- NLL_i = - log(prob[i][y[i]] ^ s[i]) = - s[i]  * log(prob([i][y[i]])
-- Mimic nn.ClassNLLCriterion:updateOutput(input, target)
-- ARGS
-- logprob : input, 2D Tensor of probabilities size = nSamples x nClasses
-- ys      : table with two elements
--           ys.y : 1D Tensor of class numbers
--           ys.s : 1D Tensor of saliences
-- CALCULATIONS
-- Define loss(prob, y, s) = \sum_i - log(prob_{i,y_i}^s_i) = \sum_i - s_i log prob_{i, y_i}
-- Since input_{a,b} = log prob_{a,b} we have
-- loss(input, y, s) = \sum_i - s_i input_{i, y_i}
function LogisticRegressionCriterion:updateOutput(logprob, ys)
   local y = ys.y
   local s = ys.s

   local nSamples = y:size(1)
   local output = 0
   for i = 1, nSamples do
      output = output - logprob[i][y[i]] * s[i]
   end
   output = output / nSamples -- always size average

   self.output = output
   return output
end


-- Mimic nn.ClassNLLCriterion:updateGradInput(input, target)
-- loss(input, y, s) = \sum_i - s_i input_{i, y_i}
-- CALCULATION
-- grad_{input_{a,b} loss =
-- grad_{input_{a,b} \sum_i - s_i input_{i, y_i} =
-- - grad_{input_{a,b} \sum_i s_i input_{i, y_i} =
-- - \sum_i grad_{input_{a,b} s_i input_{i, y_i} =
-- - \sum_i [s_i grad_{input_{a,b} input_{i, y_i} + input_{i, y_i} grad_{input_{a,b} s_i]  =
-- - \sum_i [s_i grad_{input_{a,b} input_{i, y_i} + 0]  =
-- - \sum_i [s_i grad_{input_{a,b} input_{i, y_i}]   =
-- - \sum_i [s_i (if b = y_i then 1 else 0)] 
function LogisticRegressionCriterion:updateGradInput(logprob, ys)
   local y = ys.y
   local s = ys.s

   local nSamples = logprob:size(1)

   self.gradInput:resizeAs(logprob)
   self.gradInput:zero()

   local z = (-1) / nSamples --always size average
   local gradInput = self.gradInput
   for i = 1, nSamples do
      gradInput[i][y[i]] = z * s[i] 
   end

   return self.gradInput
end

-------------------------------------------------------------------------------
-- makeFunctions
-------------------------------------------------------------------------------

function LogisticRegression.makeFunctions(augmentedX, y, s, nClasses, l2)
   print('STUB: implement l2 regularizer')
   local nSamples = augmentedX:size(1)
   local nFeatures = augmentedX:size(2)
   local ys = {y = y, s = s}

   print('nFeatures') print(nFeatures) print('nClasses') print(nClasses)
   print('LRModel', LogisticRegressionModel)
   local model = LogisticRegressionModel(nFeatures, nClasses)
   local criterion = LogisticRegressionCriterion()
   pp.table('model', model) pp.table('criterion', criterion)

   local parameters, gradParameters = model:getParameters() 

   local function lossFunction(theta)
      if parameters ~= theta then
         parameters:copy(theta) -- parameters (in model) := theta
      end

      gradParameters:zero()

      local output = model:forward(augmentedX)
      local loss = criterion:forward(output, ys)

      -- normalize for input size (is this needed?)
      return loss / nSamples
   end

   local function lossGradientFunction(theta)
      if parameters ~= theta then
         parameters:copy(theta) -- parameters (in model) := theta
      end

      gradParameters:zero()

      local output = model:forward(augmentedX)
      local loss = criterion:forward(output, ys)
      local gradCriterion = criterion:backward(output, ys)
      local dmodule2_do = model.modules[2]:backward(augmentedX, gradCriterion)
      model.modules[1]:accGradParamaters(augmentedX, dmodule2_do) -- increment gradParameters

      -- normalize for input size (is this needed?)
      return loss / nSamples, gradientParameters:div(nSamples)
   end

   return lossFunction, lossGradientFunction
end

   

