-- verify.lua
-- verify types of args and print if verbose is true

require 'affirm'

function verify(v, verbose, seq)
   -- ARGS
   -- v       : function to print argument
   -- verbose : boolean
   -- seq     : sequence
   --           {{value, 'name', 'type'}, ... }
   
   affirm.isFunction(v, 'v')
   affirm.isBoolean(verbose, 'verbose')
   affirm.isSequence(seq, 'seq')

   for i = 1, #seq do
      local triple = seq[i]
      local value = triple[1]
      local name = triple[2]
      local type = triple[3]
      affirm.isString(name, 'name of ' .. tostring(i))
      affirm.isString(type, 'type of ' .. tostring(i))
      if verbose then v(name, value) end
      local f = affirm[type]
      if f == nil then
         error('invalid type = ' .. tostring(type))
      end
      affirm[type](value, name)
   end
end -- verify