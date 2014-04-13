-- parseCommandLine.lua
-- SEE ALSO the class CommandLine which may do more of what you want

require 'makeVp'

-- pull a named value out of the command line
-- command line is coded as a sequence of -tag | --tag value
-- ARGS
-- clArgs : table from the lua interpretter
-- op     : string
--          'value'   --> return element after tag in command line as a string
--          'present' --> return true if present otherwise false
-- tag    : string, name of element sought; include any prefixes
--          ex: --myArg
-- RETURNS
-- value  : boolean if op == 'present', string or nil if op == 'value'
function parseCommandLine(clArgs, op, tag)
   local vp = makeVp(0, 'parseCommandLine')
   vp(1, 'clArgs', clArgs, 'op', op, 'tag', tag)

   -- validate args
   assert(type(op) == 'string')
   assert(op == 'value' or op == 'present')

   assert(type(clArgs) == 'table')
   if #clArgs == 0 then
      if op == 'value' then 
         return nil
      elseif op == 'present' then
         return false
      else
         error('cannot happen')
      end
   end
   assert(#clArgs > 0, 'no command line arguments found')

   assert(type(tag) == 'string')

   local i = 1  -- ignore the program name which is in position 0
   while i <= #clArgs do
      if clArgs[i] == tag then
         if op == 'present' then
            return true
         else --  op == 'value'
            return clArgs[i + 1] -- possibly nil
         end
      end
      i = i + 1
   end

   if op == 'present' then
      return false
   else -- op == 'value'
      return nil
   end
end
