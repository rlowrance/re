-- affirm.lua
-- error if value not of specified type and range
-- like assert but generates nice message

-- API overview
if false then
   affirm.isBoolean(var, 'var')
end

affirm = {}

-- generate a function 
-- affirm.affirmFunctionName(value, variableName)
local function generate(affirmFunctionName, userName)
   affirm[affirmFunctionName] = function(value, variableName)
      assert(variableName, 'missing variableName')
      if check[affirmFunctionName](value) then return end
      if affirmFunctionName == 'isNotNil' then
         affirm._errorNotNil(userName, value, variableName)
      else
         affirm._error(userName, value, variableName)
      end
   end
end

generate('isBoolean', 'boolean')
generate('isAny', 'any object including nil')
generate('isCompletion', 'Completion')
generate('isFunction', 'function')
generate('isIncompleteMatrix', 'IncompleteMatrix')
generate('isInteger', 'integer')
generate('isIntegerNonNegative', 'non-negative integer')
generate('isIntegerPositive', 'positive integer')
generate('isLog', 'Log')
generate('isNotNil', 'is not nil')
generate('isNil', 'nil')
generate('isNumber', 'number')
generate('isNumberNonNegative', 'non-negative number')
generate('isNumberPositive', 'positive number')
generate('isSequence', 'sequence')
generate('isSet', 'Set')
generate('isSequence', 'sequence')
generate('isString', 'string')
generate('isTable', 'table')
generate('isTensor', 'Tensor')
generate('isTensor1D', '1D Tensor')
generate('isTensor2D', '2D Tensor')
generate('isThread', 'thread')
generate('isUserdata', 'userdata')

--[[
function affirm.isFunction(value, name)
   if check.isFunction(value) then return end
   affirm._error('function', value, name)
end

function affirm.isIntegerPositive(value, name)
   if check.isIntegerPostive(value) then return end
   affirm._error('positive integer', value, name)
end

function affirm.isNumberPositive(value, name)
   if check.isNumberPositive(value) then return end
   affirm._error('positive number', value, name)
end

function affirm.isSet(value, name)
   if check.isSet(value) then return end
   affirm.isSet('Set', value, name)
end
   --]]

function affirm._error(kind, value, variableName)
   error(variableName .. ' (=' .. tostring(value) .. ') is not a ' .. kind)
end

function affirm._errorNotNil(kind, value, variableName)
   error(variableName .. 
         ' (=' .. 
         tostring(value) .. 
         ') is nil and should not be')
end
      