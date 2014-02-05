-- equalObjectValues.lua
-- are two arbitrary objects equal in value (not necessarily the same object)
-- ARGS
-- a      : arbitrary object
-- b      : arbitrary object
-- RETURNS
-- result : boolean
-- whynot : optional string, returned if result is false

require 'equalTensors'
require 'isTensor'
require 'makeVp'
require 'printTableValue'

-------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-------------------------------------------------------------------------------

local function errorMsg(a, b)
   return string.format('a = %s, but b = %s', tostring(a), tostring(b))
end

-- determine if key values in two tables are equal
-- require identical keys
local function equalTableKeys(tableA, tableB)
   for keyA in pairs(tableA) do
      local value = tableB[keyA]
      if value == nil then
         return false, string.format('tableA has key %s not in tableB', tostring(keyA))
      end
   end

   for keyB in pairs(tableB) do
      local value = tableA[keyB]
      if value == nil then
         return false, string.format('tableB has key %s not in tableA', tostring(keyB))
      end
   end
   return true 
end

-- determine if value in two tables are equal
-- required equality of values, not identity
local function equalTableValues(tableA, tableB)
   for keyA, valueA in pairs(tableA) do
      local valueB = tableB[keyA]
      if not equalObjectValues(valueA, valueB) then
         return false, string.format('tableA[%s] = %s, but not so in tableB', tostring(keyA), tostring(valueA))
      end
   end

   for keyB, valueB in pairs(tableB) do
      local valueA = tableA[keyB]
      if not equalObjectValues(valueA, valueB) then
         return false, string.format('tableB[%s] = %s, but not so in tableA', tostring(keyB), tostring(valueB))
      end
   end
   return true
end

-- determine if values in two tables are equal
local function equalTables(tableA, tableB)
   if tableA == tableB then
      return true
   end

   local keysEqual, whyNot = equalTableKeys(tableA, tableB)
   if not keysEqual then
      return keysEqual, whyNot
   end


   local keysEqual, whyNot = equalTableValues(tableA, tableB)
   if not keysEqual then
      return keysEqual, whyNot
   end

   return true 
end

local function equalNumbers(numberA, numberB)
   local vp = makeVp(0, 'equalNumbers')
   vp(1, 'numberA', numberA, 'numberB', numberB)
   if isnan(numberA) then 
      local bool = isnan(numberB)
      vp(2, 'bool', bool)
      if bool then
         return true
      else
         return false, errorMsg(numberA, numberB)
      end
   else
      local bool = numberA == numberB
      vp(2, 'bool', bool)
      if bool then
         return true
      else
         return false, errorMsg(numberA, numberB)
      end
   end
end

local function equalStrings(stringA, stringB)
   local bool = stringA == stringB
   if bool then
      return true
   else
      return false, errorMsg(stringA, stringB)
   end
end

local function equalBooleans(booleanA, booleanB)
   local bool = booleanA == booleanB
   if bool then
      return true
   else
      return false, errorMsg(booleanA, booleanB)
   end
end

local function equalNils(nilA, nilB)
   return true  -- we know both values are nil and there is only one nil value
end

local function equalFunctions(functionA, functionB)
   local bool = functionA == functionB
   if bool then
      return true
   else
      return false, errorMsg(functionA, functionB)
   end
end

local function equalThreads(threadA, threadB)
   local bool = threadA == threadB
   if bool then
      return true
   else
      return false, errorMsg(threadA, threadB)
   end
end

local function equalTorchTensors(tensorA, tensorB)
   local vp = makeVp(0, 'equalTorchTensors')
   vp(1, 'tensorA', tensorA, 'tensorB', tensorB)

   -- because of the recursive call, the tensors may have been reduced to numbers
   if type(tensorA) == 'number' then
      local typeB = type(tensorB)
      if typeB ~= 'number' then
         return false, string.format('a is a number, but b is a %s', typeB)
      else
         return equalNumbers(tensorA, tensorB)
      end
   else
      local nDimension = tensorA:nDimension()
      if nDimension ~= tensorB:nDimension() then
         return false, string.format('a has %d dimensions, but b has %d', tensorA:nDimension(), tensorB:nDimension())
      else
         for i = 1, tensorA:size(1) do
            -- recursively examine the rows of each tensor
            local result, whynot = equalTorchTensors(tensorA[i], tensorB[i])
            if not result then
               return false, whynot
            end
         end
         return true
      end
   end
end

local function equalTorchtypes(torchA, torchB)
   local vp = makeVp(0, 'equalTorchtypes')
   vp(1, 'torchA', torchA, 'torchB', torchB)
   if isTensor(torchA) and isTensor(torchB) then
      return equalTorchTensors(torchA, torchB)
   else
      if torchA == torchB then
         return true
      else
         return false, string.format('a is %s but b is %s', tostring(torchA), tostring(torchB))
      end
   end
end

local function equalUserdata(userdataA, userdataB)
   local vp = makeVp(0, 'equalUserdata')
   vp(1, 'userdataA', userdataA, 'userdataB', userdataB)

   -- specially handle torch types
   local torchtypeA = torch.typename(userdataA)
   local torchtypeB = torch.typename(userdataB)
   vp(2, 'torchtypeA', torchtypeA, 'torchtypeB', torchtypeB)

   if torchtypeA ~= nil and torchtypeB ~= nil then
      return equalTorchtypes(userdataA, userdataB)
   elseif torchtypeA ~= nil and torchtypeB == nil then
      return false, string.format('a is type %s but b is userdata', torchtypeA)
   elseif torchtypeA == nil and torchtypeB ~= nil then
      return false, string.format('a is userdata but b it type %s', torchtypeB)
   elseif torchtypeA == nil and torchtypeB == nil then
      if userdataA == userdataB then
         return true
      else
         return false, 'a is userdata %s but b is userdata %s', tostring(userdataA), tostring(userdataB)
      end
   else
      error('cannot happen')
   end
end



-------------------------------------------------------------------------------
-- MAIN FUNCTION
-------------------------------------------------------------------------------

function equalObjectValues(a, b)
   local vp = makeVp(0, 'equalObjectValues')
   vp(1, '\n************')
   vp(1, 'a', a, 'b', b)
   vp(1, 'type(a)', type(a), 'type(b)', type(b))
   vp(1, 'torch.typename(a)', torch.typename(a))

   if type(a) ~= type(b) then
      vp(1, 'result', false)
      return false, string.format('a has type %s, but b has type %s', type(a), type(b))
   end

   if torch.typename(a) ~= torch.typename(b) then
      return false, string.format('a has torch type %s, but b has torch type %s',
                                  torch.typename(a), torch.typename(b))
   end

   if type(a) == 'table' then
      return equalTables(a, b)

   elseif type(a) == 'number' then
      return equalNumbers(a, b)

   elseif type(a) == 'string' then
      return equalStrings(a, b)

   elseif type(a) == 'boolean' then
      return equalBooleans(a, b)

   elseif type(a) == 'nil' then
      return equalNils(a, b)

   elseif type(a) == 'function' then
      return equalFunctions(a, b)

   elseif type(a) == 'thread' then
      return equalThread(a, b)

   elseif type(a) == 'userdata' then
      return equalUserdata(a, b)

   else
      error('unknown type of a')
   end
end
