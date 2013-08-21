-- makeVerbose.lua
-- create function verbose which prints if and only if tracing

require 'affirm'
require 'check'

-- API overview
if false then
   local verbose = makeVerbose(true, 'Class:method')
   verbose('message')
   verbose('a', a)   

   local verbose, trace = makeVerbose(false, 'Class:method')
   if trace then
      -- condition code
   end
end

function makeVerbose(tracing, name)
   -- ARGS
   -- tracing : boolean
   -- name    : string, name of function or method
   -- RETURNS
   -- verbose : function to print iff tracing
   -- trace   : boolean, value of tracing
   affirm.isBoolean(tracing, 'tracing')
   affirm.isString(name, 'name')

   if tracing then
      local function verbose(msg, value1, ...)
         local largeSize = 10
         local function printLargeTensor(value1)
            local nDim = value1:nDimension()
            for i = 1, largeSize do
               if nDim == 1 
               then
                  print(string.format('[%d] = %f', i, value1[i]))
               else
                  print(string.format('[%d] =', i), value1[i])
               end
            end
            print(string.format('<another %d rows omitted>', 
                                value1:size(1) - largeSize))
         end -- printLargeTensor
         local function printLargeSequence(value1)
            for i = 1, largeSize do
               print(string.format(' [%d] = %s', i, tostring(value1[i])))
            end
            print(string.format('<another %d elements omitted>',
                                #value1 - largeSize))
         end -- printLargeSequence
         if value1 == nil then
            print(name .. ': ' .. msg)
         elseif type(value1) == 'table' or 
            type(value1) == 'userdata' then
            -- start new line if printing table or userdata
            print(name .. ': ' .. msg)
            -- print value1 and other args in the ...
            -- if the type of value1 is a Tensor, 
            -- only print the first 10 rows
            if check.isTensor(value1) and value1:size(1) > largeSize then
               printLargeTensor(value1)
               print(...)
            elseif type(value1) == 'table' 
               and #value1 > largeSize and
               check.isSequence(value1) then
               printLargeSequence(value1)
               print(...)
            elseif type(value1) == 'table' then
               print(value1)
               print(...)
            else
               print(value1, ...)         
            end
         else
            print(name .. ': ' .. msg, value1, ...)
         end
      end
      return verbose, tracing
   else
      local function verbose(...)
      end
      return verbose, tracing
   end
end -- makeVerbose
