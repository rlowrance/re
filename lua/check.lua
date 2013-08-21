-- check.lua
-- return true or false depending on value

check = {}

function check.isBoolean(value)
   return
      value ~= nil and
      type(value) == 'boolean'
end

function check.isAny(value)
   return true
end 

function check.isCompletion(value)
   return
      value ~= nil and
      torch.typename(value) == 'Completion'
end

function check.isFunction(value)
   return
      value ~= nil and
      type(value) == 'function'
end

function check.isIncompleteMatrix(value)
   return
      value ~= nil and
      torch.typename(value) == 'IncompleteMatrix'
end
                                   
function check.isInteger(value)
   return
      value ~= nil and
      type(value) == 'number' and
      math.floor(value) == value
end

function check.isIntegerNonNegative(value)
   return 
      check.isInteger(value) and
      value >= 0
end

function check.isIntegerPositive(value)
   return
      check.isInteger(value) and
      value > 0
end

function check.isLog(value)
   return
      value ~= nil and
      torch.typename(value) == 'Log'
end

function check.isNotNil(value)
   return
      value ~= nil
end

function check.isNil(value)
   return 
      value == nil
end

function check.isNumber(value)
   return
      value ~= nil and
      type(value) == 'number'
end

function check.isNumberNonNegative(value)
   return
      check.isNumber(value) and
      value >= 0
end

function check.isNumberPositive(value)
   return
      check.isNumber(value) and
      value > 0
end

function check.isSet(value)
   return
      value ~= nil and
      torch.typename(value) == 'Set'
end

function check.isSequence(value)
   -- check if number of iterants in pairs and ipairs is the same
   -- ref: http://stackoverflow.com/questions/6077006/how-can-i-check-if-a-lua-table-contains-only-sequential-numeric-indices

   local function numKeys(value)
      local count = 0
      for _, _ in pairs(value) do
         count = count + 1 
      end
      return count
   end

   local function numIndices(value)
      local count = 0
      for _, _ in ipairs(value) do
         count = count + 1
      end
      return count
   end

   return
      value ~= nil and
      type(value) == 'table' and
      numKeys(value) == numIndices(value)
end

function check.isString(value)
   return
      value ~= nil and
      type(value) == 'string'
end

function check.isTable(value)
   return
      value ~= nil and
      type(value) == 'table'
end

function check.isTensor(value)
   -- protect against torch.typename returning a nil value
   -- in that case, string.match fails
   local typename = torch.typename(value)
   return 
      value ~= nil and
      typename ~= nil and
      string.match(typename, 'torch.*Tensor') ~= nil
end

function check.isTensor1D(value)
   return
      check.isTensor(value) and
      value:nDimension() == 1
end

function check.isTensor2D(value)
   return
      check.isTensor(value) and
      value:nDimension() == 2
end

function check.isThread(value)
   return
      value ~= nil and
      type(value) == 'thread'
end

function check.isUserdata(value)
   return
      value ~= nil and
      type(value) == 'userdata'
end