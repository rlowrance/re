-- validateAttributes.lua
-- modeled after MATLAB's validateattributes function

require 'makeVp'

-- check type and attributes of a value
-- ARGS:
-- value         : arbitrary object
-- typenames     : a typename or sequence of typenames
--                 a typename is a torch type name returned by type(value)
--                 or a torch tensor name 'Tensor' or 'torch.TYPETensor'
--                 type(value) \in {'number', 'boolean', 'string', ...}
-- attributeName : optional string. Each must hold
-- attributeCode : optional object dependent on string
-- RETURNS nil
--
-- EXAMPLES:
-- validateAttributes(x, 'number', 'positive')
-- validateAttributes(x, 'number', '<', 20)
-- validateAttributes(X, 'Tensor')
function validateAttributes(value, typeNames, ...)
   local vp = makeVp(0, 'validateAttributes')
   vp(1, 'value', value)
   vp(1, 'typeNames', typeNames)

   -- convert a single typeName into a sequence of typeNames of length 1
   if type(typeNames) == 'string' then
      typeNames = {typeNames}
   end
   assert(type(typeNames) == 'table')

   local typeOk = false
   local valueType = type(value)
   local valueTorchType = torch.typename(value)
   vp(2, 'valueType', valueType, 'valueTorchType', valueTorchType)
   for _, typeName in pairs(typeNames) do
      -- check special type names first
      if valueTorchType ~= nil then
         if typeName == 'Tensor' and
            (valueTorchType == 'torch.DoubleTensor' or
             valueTorchType == 'torch.FloatTensor' or
             valueTorchType == 'torch.LongTensor' or
             valueTorchType == 'torch.IntTensor' or
             valueTorchType == 'torch.ShortTensor' or
             valueTorchType == 'torch.CharTensand' or
             valueTorchType == 'torch.ByteTensor') then
               typeOk = true
               break
         elseif typeName == valueTorchType then
            typeOk = true
            break
         end
      else
         if typeName == valueType then
            typeOk = true
            break
         elseif typeName == 'file' and valueType == 'userdata' then
            typeOk = true  -- there is no precise test for file type
            break
         end
      end
   end
   if typeOk == false then
      if valueTorchType == nil then
         vp(0, string.format('value has type %s, not one of', valueType), typeNames)
      else
         vp(0, string.format('value has type %s, not one of', valueTorchType), typeNames)
      end
      error('bad type')
   end

   -- check attributes
   local attributes = {...}
   vp(1, 'attributes', attributes)

   local index = 0
   while index < #attributes do
      index = index + 1
      local attribute = attributes[index]
      vp(2, 'attribute', attribute)
      assert(type(attribute) == 'string',
             string.format('attribute (%s) is not a string', tostring(attribute)))

      if attribute == '1d' or attribute == '1D' then
         assert(value:dim() == 1, 'value is not 1D')

      elseif attribute == '2d' or attribute == '2D' then
         assert(value:dim() == 2, 'value is not 2D')

      elseif attribute == 'column' then
         assert(value:dim() == 2 and value:size(2) == 1, 'value is not N x 1')

      elseif attribute == 'row' then
         assert(value:dim() == 2 and value:size(1) == 1, 'value is not 1 x N')

      elseif attribute == 'scalar' then
         assert(value:dim() == 2 and value:size(1) == 1 and value:size(2) == 1,
                'value is not 1 x 1')

      elseif attribute == 'vector' then
         assert(value:dim() == 2 and (value:size(1) == 1 or value:size(2) == 1),
                'value is not a row, column, or scalar')

      elseif attribute == 'size' then
         index = index + 1
         local sizes = attributes[index]
         if valueType == 'table' then
            assert(sizes ==  #value,
                   string.format('value has size %d, not expected %d',
                                 sizes, #value))
         else
            local valueSizes = value:size()
            assert(#sizes == value:dim(),
                   string.format('value has %d dimensions, not expected %d',
                                 value:dim(), #sizes))
            for d = 1, #sizes do
               assert(sizes[d] == valueSizes[d],
                      string.format('value dimensions %d has size %d, not expected %d',
                                    d, valueSizes[d], sizes[d]))
            end
         end

      elseif attribute == 'numel' or attribute == 'nElement' then
         index = index + 1
         local n = attributes[index]
         assert(n == value:nElement(),
                string.format('value has %d elements, not expected %d',
                              value:nElement(), n))

      elseif attribute == 'ncols' or attribute == 'nCols' then
         index = index + 1
         local n = attributes[index]
         assert(n == value:size(2),
                string.format('value has %d columns, not expected %d',
                              value:size(2), n))

      elseif attribute == 'nrows' or attribute == 'nRows' then
         index = index + 1
         local n = attributes[index]
         assert(n == value:size(1),
                string.format('value has %d rows, not expected %d',
                              value:size(1), n))

      elseif attribute == 'ndims' or attribute == 'nDimension' then
         index = index + 1
         local n = attributes[index]
         assert(n == value:nDimension(1),
                string.format('value has %d dimensions, not expected %d',
                              value:nDimension(), n))

      elseif attribute == 'square' then
         assert(value:nDimension() == 2,
                string.format('value has %d dimensions, so is not square',
                              value:nDimension()))
         assert(value:size(1) == value:size(2),
                string.format('value is %d x %d, so is not square',
                              value:dim(1), value:dim(2)))

      elseif attribute == 'nonempty' or attribute == 'nonEmpty' then
         assert(value:nElement() ~= 0,
                'value has no elements, so it is not nonempty')

      elseif attribute == '>' then
         index = index + 1
         local n = attributes[index]
         if valueType == 'number' then
            assert(value > n,
                   string.format('value (%f) not > %f', value, n))
         else
            assert(torch.sum(torch.gt(value, n)) == value:nElement(),
                   string.format('value has element not > %f', n))
         end

      elseif attribute == '>=' then
         index = index + 1
         local n = attributes[index]
         if valueType == 'number' then
            assert(value >= n,
                   string.format('value (%f) not >= %f', value, n))
         else
            assert(torch.sum(torch.ge(value, n)) == value:nElement(),
                   string.format('value has element not >= %f', n))
         end

      elseif attribute == '<' then
         index = index + 1
         local n = attributes[index]
         if valueType == 'number' then
            assert(value < n,
                   string.format('value (%f) not < %f', value, n))
         else
         assert(torch.sum(torch.lt(value, n)) == value:nElement(),
                string.format('value has element not < %f', n))
         end

      elseif attribute == '<=' then
         index = index + 1
         local n = attributes[index]
         if valueType == 'number' then
            assert(value <= n,
                   string.format('value (%f) not <= %f', value, n))
         else
            assert(torch.sum(torch.le(value, n)) == value:nElement(),
                   string.format('value has element not <= %f', n))
         end

      elseif attribute == 'binary' then
         if valueType == 'number' then
            assert(value == 0 or value == 1,
                   string.format('value (%f) is not 0 or 1', value))
         else
            assert(torch.sum(torch.eq(value, 0) + torch.eq(value, 1)) == 
                   value:nElement(),
                   'value has an element not in {0, 1}')
         end

      elseif attribute == 'even' then
         if valueType == 'number' then
            assert(value %2 == 0,
                   string.format('value (%f) is not even', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] % 2 == 0,
                      string.format('element at offset %d is not even', i))
            end
         end

      elseif attribute == 'odd' then
         if valueType == 'number' then
            assert(value % 2 == 1,
                   string.format('value (%f) is not odd', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] % 2 == 1,
                      string.format('element at offset %d is not odd', i))
            end
         end

      elseif attribute == 'integer' then
         if valueType == 'number' then
            assert(value == math.floor(value),
                   string.format('value (%f) is not an integer', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] == math.floor(storage[i]),
                      string.format('element at offset %d is not an integer', i))
            end
         end

      elseif attribute == 'finite' then
         if valueType == 'number' then
            assert(value ~= math.huge and value ~= -math.huge,
                   string.format('value (%f) is infinite', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] ~= math.huge and storage[i] ~= -math.huge,
                      string.format('element at offset %d is infinite', i))
            end
         end

      elseif attribute == 'nonnan' or attribute == 'nonNan' or attribute == 'nonNaN' then
         if valueType == 'number' then
            assert(value == value,
                   string.format('value (%f) is NaN', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] == storage[i],  -- not true only if value is NaN
                  string.format('element at offset %d is NaN', i))
            end
         end

      elseif attribute == 'nonnegative' or attribute == 'nonNegative' then
         if valueType == 'number' then
            assert(value >= 0,
                   string.format('value (%f) is negative', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] >= 0,
                      string.format('element at offset %d is negative', i))
            end
         end

      elseif attribute == 'nonzero' or attribute == 'nonZero' then
         if valueType == 'number' then
            assert(value ~= 0,
                   string.format('value (%f) is zero', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] ~= 0,
                      string.format('element at offset %d is zero', i))
            end
         end

      elseif attribute == 'positive' then
         if valueType == 'number' then
            assert(value > 0,
                   string.format('value (%f) is not positive', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] > 0,
                      string.format('element at offset %d is not positive', i))
            end
         end

      elseif attribute == 'negative' then
         if valueType == 'number' then
            assert(value < 0,
                   string.format('value (%f) is not negative', value))
         else
            local storage = value:storage()
            for i = 1, storage:size() do
               assert(storage[i] < 0,
                      string.format('element at offset %d is not negative', i))
            end
         end
      else
         error(string.format('unimplemented attribute %s', attribute))
      end
   end
end
