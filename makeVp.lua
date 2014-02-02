-- makeVp.lua
-- make a verbose print function

-- API overview
if false then
   local vp, verboseLevel, prefix, vpTable = makeVp(2, 'functionName')
   local ifvp1 = verboseLevel >= 1
   local ifvp2 = verboseLevel >= 2
   
   if vp2 then vp(2, 'name', value) end  -- avoid evaluating args to vp()
   
   vp(2, 'var name', var)  -- print if verbose is at least 2
   vp('var name', var)     -- print if verbose is at least 1
   vp(2, 'string')         -- print if verbose is at least 2
   vp(var)                 -- print if verbose is at least 1
   vp(2, 'table name', table)  -- print k,v pairs if verbose is at least 2
   
   if verboseLevel >= 3 then action() end
end
--require 'keyboard'
require 'torch'

-- create verbosePrint function
-- ARGS:
-- verbose : number, if level is at least verbose, output is printed
-- prefix  : optional string, default ''
--           the name is prefixed by this string so that what is printed is:
--             prefix .. name .. '=' .. representation(value)
--           where representation(value) is a string that depends on the type
--           of value
-- RETURNS:
-- vp      : function(level, name, value) returns nil
-- verbose : number, the argument verbose
-- prefix  : string, the argument prefix
function makeVp(verboseVar, prefix)
   assert(type(verboseVar) == 'number',
          'verboseVar not a number')

   --print(verboseVar) print(prefix)

   local prefixString = ''
   if type(prefix) == 'string' then
      prefixString = prefix .. ': '
   end

   -- if s begins with \n, print blank line and return s without the \n
   local function maybeSkipLine(s)
      if type(s) == 'string' and string.sub(s, 1, 1) == '\n' then
         print(' ')
         return string.sub(s, 2)  -- remove the \n character
      else
         return s
      end
   end


   local function vp1(value)
      value = maybeSkipLine(value)
      print(prefixString .. tostring(value))
   end

   -- conditionally print 1 value
   local function cp1(level, value)
      --print('cp1 value=' .. tostring(value))
      if level <= verboseVar then
         vp1(value)
      end
   end
   
   local function vp2(name, value)
      --print('vp2()') print('name') print(name) print('value') print(value) print('done')
      --keyboard()
      --if name == '\npredictionAttributes' or name == '\nlambda' then
      --   print('entered vp2') print(name) print(value)
      --end
      name = maybeSkipLine(name)
      if type(value) == 'userdata' or type(value) == 'table' then
         if torch.typename(value) == 'Dataframe' then
            print(prefixString .. name .. '=a Dataframe')
            value:print()
         elseif torch.typename(value) == 'NamedMatrix' then
            print(prefixString .. name .. '=a NamedMatrix')
            value:print()
         else
            print(prefixString .. name .. '=')
            print(value)
         end
      else
         print(prefixString .. name .. '=' .. tostring(value))
      end
   end

   -- conditionally print 2 values
   local function cp2(level, name, value)
      if level <= verboseVar then
         vp2(name, value)
      end
   end
   
   local function vp(level, name, value, ...)
      --if name == '\npredictionAttributes' or name == '\nlambda' then
      --   print('entered vp') print(level) print(name) print(value) print(...)
      --end
      -- handle missing args
      -- put most frequent case first
      if level ~= nil and name ~= nil and value ~= nil then
         -- full call, which may or may not print
         if level <= verboseVar then
            vp2(name, value)

            -- handle varargs
            local varargs = {...}

            if #varargs == 0 then
               return
            end

            -- step through the name-value pairs in varargs
            local index = 1
            while varargs[index] ~= nil do
               vp2(varargs[index], varargs[index + 1])
               index = index + 2
            end
         end
      elseif level ~= nil and name ~=nil and value == nil then
         --print('special case') print(level) print(name) print(verboseVar)
         -- vp(level, name, nil)
         if type(level) == 'number' then
            cp1(level, name)
         else
            cp2(1, level, name)
         end
      elseif level ~= nil and name == nil and value ~= nil then
         cp2(1, level, value)
      elseif level ~= nil and name == nil and value == nil then
         cp1(1, level)
      elseif level == nil and name ~= nil and value ~= nil then
         cp2(1, name, value)
      elseif level == nil and name~= nil and value == nil then
         cp1(1, name)
      elseif level == nil and name == nil and value ~= nil then
         cp1(1, value)
      elseif level == nil and name == nil and value == nil then
         cp1(1, nil)
      end
   end

   local function vpTable(level, name, value)
      assert(type(level) == 'number', 'level is not a number')
      assert(type(name) == 'string', 'name is not a string')
      assert(type(value) == 'table', 'value is not a table')
      for k, v in pairs(value) do
         vp(level, name .. '[' .. tostring(k) .. ']=', v)
      end
   end

   --print(vp) print(verboseVar) print(prefix)
   return vp, verboseVar, prefix, vpTable
end
      
